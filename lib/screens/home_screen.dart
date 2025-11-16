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

  @override
  void initState() {
    super.initState();
    _loadDistricts();
    _loadAllPosts();
  }

  Future<void> _loadDistricts() async {
    final districts = await _firebaseService.getDistricts();
    if (districts.isEmpty) {
      await _firebaseService.initializeDistricts();
      final newDistricts = await _firebaseService.getDistricts();
      setState(() {
        _districts = newDistricts;
        _isLoading = false;
      });
    } else {
      setState(() {
        _districts = districts;
        _isLoading = false;
      });
    }
  }

  void _loadAllPosts() {
    // Listen to all posts for real-time updates
    _firebaseService.getAllPostsStream().listen((posts) {
      if (mounted) {
        setState(() {
          _allPosts = posts;
        });
      }
    });
  }

  void _navigateToForum(District district) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ForumScreen(district: district),
      ),
    );
  }

  void _navigateToPostDetail(Post post) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => PostDetailScreen(post: post),
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

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
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
              CupertinoPageRoute(
                builder: (context) => const DebugScreen(),
              ),
            );
          },
        ),
      ),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                // Map Section
                Expanded(
                  flex: 2,
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: const LatLng(3.1390, 101.6869), // KL
                          initialZoom: 10.0,
                          minZoom: 6.0,
                          maxZoom: 18.0,
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
                            MarkerLayer(
                              markers: _allPosts.map((post) {
                                // Use post's exact coordinates if available, otherwise use district center
                                double lat;
                                double lon;
                                
                                if (post.latitude != null && post.longitude != null) {
                                  lat = post.latitude!;
                                  lon = post.longitude!;
                                } else {
                                  // Fallback to district center for old posts without coordinates
                                  final district = _districts.firstWhere(
                                    (d) => d.id == post.districtId,
                                    orElse: () => District(
                                      id: '',
                                      name: '',
                                      latitude: 3.1390,
                                      longitude: 101.6869,
                                      state: '',
                                    ),
                                  );
                                  
                                  if (district.id.isEmpty) return null;
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
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: post.category.color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: CupertinoColors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: CupertinoColors.black.withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        post.category.icon,
                                        color: CupertinoColors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                );
                              }).whereType<Marker>().toList(),
                            ),
                          // District markers (forums)
                          MarkerLayer(
                            markers: _districts.map((district) {
                              return Marker(
                                point: LatLng(district.latitude, district.longitude),
                                width: 80,
                                height: 80,
                                child: GestureDetector(
                                  onTap: () => _navigateToForum(district),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.systemRed,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: CupertinoColors.black.withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.location_solid,
                                          color: CupertinoColors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: CupertinoColors.black.withValues(alpha: 0.2),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          district.name,
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: CupertinoColors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
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
                    ],
                  ),
                ),
                // District List Section
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: CupertinoColors.systemGroupedBackground,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                          child: Text(
                            'Regional Forums',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ListView.separated(
                                itemCount: _districts.length,
                                separatorBuilder: (context, index) => Container(
                                  height: 0.5,
                                  margin: const EdgeInsets.only(left: 56),
                                  color: CupertinoColors.separator,
                                ),
                                itemBuilder: (context, index) {
                                  final district = _districts[index];
                                  return CupertinoListTile(
                                    leading: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemRed.withValues(alpha: 0.1),
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
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

