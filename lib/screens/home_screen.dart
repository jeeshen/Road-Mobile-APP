import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/district.dart';
import '../models/post.dart';
import '../models/post_category.dart';
import '../services/firebase_service.dart';
import 'forum_screen.dart';
import 'debug_screen.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<District> _districts = [];
  List<Post> _allPosts = [];
  bool _isLoading = true;
  StreamSubscription<List<Post>>? _postsSubscription;
  Map<String, District>? _districtMap;
  List<Marker>? _cachedPostMarkers;
  List<Marker>? _cachedDistrictMarkers;

  @override
  void initState() {
    super.initState();
    _loadDistricts();
    _loadAllPosts();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    super.dispose();
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
    if (_cachedDistrictMarkers != null) {
      return _cachedDistrictMarkers!;
    }

    _cachedDistrictMarkers = _districts.map((district) {
      return Marker(
        point: LatLng(district.latitude, district.longitude),
        width: 70,
        height: 90,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () => _navigateToForum(district),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // iOS-style pin head
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
                    // Post markers (incidents)
                    if (_allPosts.isNotEmpty)
                      MarkerLayer(markers: _buildPostMarkers()),
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
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  child: Text(
                                    'Regional Forums',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
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
