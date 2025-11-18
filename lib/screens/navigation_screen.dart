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
import '../widgets/animated_character_marker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NavigationScreen extends StatefulWidget {
  final LatLng destination;
  final String destinationName;
  final Position currentPosition;
  final List<Post> allPosts;
  final List<District> districts;

  const NavigationScreen({
    super.key,
    required this.destination,
    required this.destinationName,
    required this.currentPosition,
    required this.allPosts,
    required this.districts,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final nav_service.NavigationService _navigationService =
      nav_service.NavigationService();
  final LocationService _locationService = LocationService();
  final VoiceAlertService _voiceService = VoiceAlertService();
  final MapController _mapController = MapController();

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
  List<UserLocation> _liveUsers = [];
  User? _currentUser;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.currentPosition;
    _calculateRoutes();
    _loadLiveUsers();
    _loadCurrentUser();
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

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _liveUsersSubscription?.cancel();
    _navigationTimer?.cancel();
    _voiceService.dispose();
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

    setState(() {
      _isNavigating = true;
    });

    // Announce navigation start
    _voiceService.announceNavigationStart(
      widget.destinationName,
      _selectedRoute!.durationText,
    );

    // Start position tracking
    _positionSubscription = _locationService
        .getPositionStream(accuracy: LocationAccuracy.high, distanceFilter: 10)
        .listen(_handlePositionUpdate);

    // Start navigation monitoring
    _navigationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkNavigationState();
    });
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
    });
    _positionSubscription?.cancel();
    _navigationTimer?.cancel();
    _voiceService.stop();
  }

  void _handlePositionUpdate(Position position) {
    if (!mounted || _selectedRoute == null) return;

    setState(() {
      _currentPosition = position;
      _currentSpeed = position.speed * 3.6; // Convert m/s to km/h
      // Character is moving if speed is above 1 km/h (approx 0.28 m/s)
      _isMoving = position.speed > 0.28;
    });

    // Live location updates handled by location sharing service

    // Update map position
    _mapController.move(LatLng(position.latitude, position.longitude), 17.0);

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

  final Set<String> _announcedPosts = {};

  void _showNearbyPostAlert(Post post, double distance) {
    // Prevent duplicate alerts
    if (_announcedPosts.contains(post.id)) return;
    _announcedPosts.add(post.id);

    // Show alert banner
    if (mounted) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => CupertinoAlertDialog(
          title: const Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: CupertinoColors.systemOrange,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(child: Text('Nearby Alert')),
            ],
          ),
          content: Text(
            '${distance.toInt()}m ahead: ${post.content.length > 80 ? '${post.content.substring(0, 80)}...' : post.content}',
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

  void _handleArrival() {
    _voiceService.announceArrival();
    _stopNavigation();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Arrived'),
        content: Text('You have arrived at ${widget.destinationName}'),
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
    return CupertinoPageScaffold(
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
            ? CupertinoButton(
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
                    initialZoom: _isNavigating ? 17.0 : 13.0,
                    minZoom: 10.0,
                    maxZoom: 19.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
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
                    // Live user markers
                    MarkerLayer(markers: _buildLiveUserMarkers()),
                    // Destination marker
                    MarkerLayer(markers: [_buildDestinationMarker()]),
                    // Current position marker
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
    // Show character avatar only if live sharing is enabled AND currently navigating
    if (_liveLocationEnabled &&
        _isNavigating &&
        _currentUser != null &&
        _currentUser!.selectedCharacter != null) {
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

    // Default blue dot
    return Marker(
      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      width: 50,
      height: 50,
      alignment: Alignment.center,
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
          // Inner solid circle
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
    return _liveUsers.map((userLoc) {
      return Marker(
        point: LatLng(userLoc.latitude, userLoc.longitude),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: CupertinoColors.systemBlue, width: 2),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemBlue.withOpacity(0.4),
                blurRadius: 6,
              ),
            ],
          ),
          child: ClipOval(
            child: userLoc.selectedCharacter != null
                ? Image.asset(
                    Character.getAllCharacters()
                        .firstWhere((c) => c.id == userLoc.selectedCharacter!)
                        .idleAction
                        .assetPath,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: CupertinoColors.systemGrey,
                    child: const Icon(
                      CupertinoIcons.person_fill,
                      size: 20,
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
          child: ListView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
        );
      },
    );
  }

  Widget _buildNavigationInfoPanel() {
    return Stack(
      children: [
        // Turn instruction at top
        if (_currentSegment != null && _distanceToNextInstruction != null)
          Positioned(
            top: 0,
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
                          _mapController.move(
                            LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            17.0,
                          );
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
                    // Voice toggle
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _voiceEnabled = !_voiceEnabled;
                        });
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
                        child: Icon(
                          _voiceEnabled
                              ? CupertinoIcons.speaker_2_fill
                              : CupertinoIcons.speaker_slash_fill,
                          color: _voiceEnabled
                              ? CupertinoColors.systemBlue
                              : CupertinoColors.systemGrey,
                          size: 22,
                        ),
                      ),
                    ),
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
}
