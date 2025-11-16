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
import '../services/analytics_service.dart';
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
  List<Marker>? _cachedDistrictMarkers;
  List<Marker>? _cachedEmergencyMarkers;
  List<CircleMarker>? _cachedHeatmapCircles;
  District? _currentDistrict;
  String? _districtSummary;
  bool _isLoadingSummary = false;
  String? _todaySummary;
  bool _isLoadingTodaySummary = false;
  bool _showHeatmap = false;
  bool _showEmergencies = true;

  @override
  void initState() {
    super.initState();
    _loadDistricts();
    _loadAllPosts();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _startLocationTracking() async {
    final hasPermission = await _locationService.checkPermission();
    if (!hasPermission) {
      return;
    }

    _positionSubscription = _locationService.getPositionStream().listen(
      (position) {
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
        _cachedDistrictMarkers = null; // Invalidate cache
        _isLoading = false;
      });
    } else {
      setState(() {
        _districts = districts;
        _districtMap = {for (var d in districts) d.id: d};
        _cachedDistrictMarkers = null; // Invalidate cache
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
          _cachedHeatmapCircles = null;
        });
        _loadTodaySummary();
      }
    });
  }

  Future<void> _loadTodaySummary() async {
    if (_chatGPTService == null) return;

    setState(() {
      _isLoadingTodaySummary = true;
    });

    try {
      final summary = await _chatGPTService.generateTodayTrafficSummary(
        _allPosts,
      );
      if (mounted) {
        setState(() {
          _todaySummary = summary;
          _isLoadingTodaySummary = false;
        });
      }
    } catch (e) {
      print('Error loading today summary: $e');
      if (mounted) {
        setState(() {
          _isLoadingTodaySummary = false;
        });
      }
    }
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
    if (_cachedDistrictMarkers != null && _districtMap != null) {
      return _cachedDistrictMarkers!;
    }

    final postCounts = _analyticsService.getPostCountsByDistrict(_allPosts);

    _cachedDistrictMarkers = _districts.map((district) {
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
                // iOS-style pin head with post count badge
                Stack(
                  alignment: Alignment.topRight,
                  children: [
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
                            color: CupertinoColors.black.withValues(alpha: 0.3),
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
                    // Post count badge
                    if (postCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
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
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            postCount > 99 ? '99+' : postCount.toString(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: CupertinoColors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                // iOS-style pin tail
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

    return _cachedDistrictMarkers!;
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

  void _navigateToCreatePostWithLocation(District district, LatLng location) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => CreatePostScreen(
          district: district,
          latitude: location.latitude,
          longitude: location.longitude,
        ),
      ),
    );
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
                  options: MapOptions(
                    initialCenter: const LatLng(3.1390, 101.6869), // KL
                    initialZoom: 10.0,
                    minZoom: 6.0,
                    maxZoom: 18.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: (tapPosition, point) {
                      _showCreatePostDialog(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      // Using CartoDB for better styling
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.roadmobile.app',
                    ),
                    // Heatmap layer
                    if (_showHeatmap)
                      CircleLayer(circles: _buildHeatmapCircles()),
                    // Post markers (incidents)
                    if (_allPosts.isNotEmpty)
                      MarkerLayer(markers: _buildPostMarkers()),
                    // Emergency markers
                    MarkerLayer(markers: _buildEmergencyMarkers()),
                    // District markers (forums)
                    MarkerLayer(markers: _buildDistrictMarkers()),
                  ],
                ),
                // Map legend
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                // Today's Traffic Summary Panel
                Positioned(
                  top: 16,
                  left: 16,
                  right: 200,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.chart_bar_alt_fill,
                              size: 16,
                              color: CupertinoColors.systemBlue,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Today\'s Summary',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (_chatGPTService != null)
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minSize: 0,
                                onPressed: _loadTodaySummary,
                                child: Icon(
                                  CupertinoIcons.arrow_clockwise,
                                  size: 14,
                                  color: _isLoadingTodaySummary
                                      ? CupertinoColors.tertiaryLabel
                                      : CupertinoColors.systemBlue,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_isLoadingTodaySummary)
                          const CupertinoActivityIndicator()
                        else if (_todaySummary != null) ...[
                          Text(
                            _todaySummary!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.label,
                              height: 1.4,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final todayData = _analyticsService
                                  .getTodayTrafficData(_allPosts);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(
                                    todayData.riskLevel.colorValue,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Color(
                                      todayData.riskLevel.colorValue,
                                    ).withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Color(
                                          todayData.riskLevel.colorValue,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Risk: ${todayData.riskLevel.displayName}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(
                                          todayData.riskLevel.colorValue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ] else
                          const Text(
                            'Loading summary...',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Draggable Regional Forums Panel
                DraggableScrollableSheet(
                  initialChildSize: 0.33, // Start at 33% of screen height
                  minChildSize: 0.33, // Minimum 33% of screen height
                  maxChildSize: 0.95, // Maximum 95% of screen height
                  snap: true,
                  snapSizes: const [0.33, 0.95],
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
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
