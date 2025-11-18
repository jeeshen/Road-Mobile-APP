import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/post.dart' as models;
import '../models/district.dart';

enum RouteType { fastest, safest, balanced }

enum NavRiskLevel { low, medium, high, critical }

class RouteSegment {
  final LatLng start;
  final LatLng end;
  final double distance; // in meters
  final double duration; // in seconds
  final List<RiskPoint> riskPoints;
  final String instruction;

  RouteSegment({
    required this.start,
    required this.end,
    required this.distance,
    required this.duration,
    required this.riskPoints,
    required this.instruction,
  });
}

class RiskPoint {
  final LatLng location;
  final NavRiskLevel level;
  final String description;
  final String type; // 'accident', 'roadblock', 'weather', 'damage', etc.
  final DateTime timestamp;
  final double radiusMeters;

  RiskPoint({
    required this.location,
    required this.level,
    required this.description,
    required this.type,
    required this.timestamp,
    this.radiusMeters = 100.0,
  });

  bool isNearRoute(LatLng point, double thresholdMeters) {
    final distance = _calculateDistance(location, point);
    return distance <= (radiusMeters + thresholdMeters);
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }
}

class NavigationRoute {
  final String id;
  final List<LatLng> polyline;
  final List<RouteSegment> segments;
  final double totalDistance; // in meters
  final double totalDuration; // in seconds
  final RouteType type;
  final double safetyScore; // 0-100, higher is safer
  final List<RiskPoint> riskPoints;
  final String summary;
  final double estimatedTollPrice; // in MYR

  NavigationRoute({
    required this.id,
    required this.polyline,
    required this.segments,
    required this.totalDistance,
    required this.totalDuration,
    required this.type,
    required this.safetyScore,
    required this.riskPoints,
    required this.summary,
    this.estimatedTollPrice = 0.0,
  });

  String get distanceText {
    if (totalDistance < 1000) {
      return '${totalDistance.toStringAsFixed(0)} m';
    }
    return '${(totalDistance / 1000).toStringAsFixed(1)} km';
  }

  String get durationText {
    final minutes = (totalDuration / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours h $remainingMinutes min';
  }

  String get safetyText {
    if (safetyScore >= 80) return 'Very Safe';
    if (safetyScore >= 60) return 'Safe';
    if (safetyScore >= 40) return 'Moderate';
    if (safetyScore >= 20) return 'Risky';
    return 'High Risk';
  }
}

class NavigationService {
  static const double _averageSpeedKmh = 60.0; // Average driving speed

  // OSRM Public API (completely free, no API key needed!)
  // Uses OpenStreetMap data for routing
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  // Generate alternative routes
  Future<List<NavigationRoute>> calculateRoutes({
    required LatLng origin,
    required LatLng destination,
    required List<models.Post> allPosts,
    required List<District> districts,
  }) async {
    // Extract risk points from posts
    final riskPoints = _extractRiskPoints(allPosts, districts);

    // Generate 3 different routes with different parameters
    final routes = <NavigationRoute>[];

    // Route 1: Fastest (direct route, no avoidance)
    final fastestRoute = await _generateRoute(
      origin: origin,
      destination: destination,
      type: RouteType.fastest,
      riskPoints: riskPoints,
      avoidanceWeight: 0.0, // No risk avoidance - fastest path
      routeVariant: 0,
    );
    routes.add(fastestRoute);

    // Route 2: Safest (avoids all risk points)
    final safestRoute = await _generateRoute(
      origin: origin,
      destination: destination,
      type: RouteType.safest,
      riskPoints: riskPoints,
      avoidanceWeight: 1.0, // Maximum risk avoidance
      routeVariant: 1,
    );
    routes.add(safestRoute);

    // Route 3: Balanced (moderate avoidance, alternative path)
    final balancedRoute = await _generateRoute(
      origin: origin,
      destination: destination,
      type: RouteType.balanced,
      riskPoints: riskPoints,
      avoidanceWeight: 0.5, // Moderate risk avoidance
      routeVariant: 2,
    );
    routes.add(balancedRoute);

    return routes;
  }

  // Extract risk points from forum posts
  List<RiskPoint> _extractRiskPoints(
    List<models.Post> posts,
    List<District> districts,
  ) {
    final riskPoints = <RiskPoint>[];
    final now = DateTime.now();

    for (final post in posts) {
      // Only consider recent posts (last 48 hours)
      final age = now.difference(post.createdAt);
      if (age.inHours > 48) continue;

      // Get location from post or district
      LatLng? location;
      if (post.latitude != null && post.longitude != null) {
        location = LatLng(post.latitude!, post.longitude!);
      } else {
        final district = districts.firstWhere(
          (d) => d.id == post.districtId,
          orElse: () => districts.first,
        );
        location = LatLng(district.latitude, district.longitude);
      }

      // Determine risk level based on post category and AI risk level
      NavRiskLevel level = NavRiskLevel.low;
      String type = 'general';

      // Map post risk level to navigation risk level
      if (post.riskLevel != null) {
        switch (post.riskLevel!) {
          case models.RiskLevel.low:
            level = NavRiskLevel.low;
            break;
          case models.RiskLevel.medium:
            level = NavRiskLevel.medium;
            break;
          case models.RiskLevel.high:
            level = NavRiskLevel.high;
            break;
          case models.RiskLevel.critical:
            level = NavRiskLevel.critical;
            break;
        }
      }

      // Map category to type
      if (post.category.name.toLowerCase().contains('accident')) {
        type = 'accident';
        if (level == NavRiskLevel.low) level = NavRiskLevel.high;
      } else if (post.category.name.toLowerCase().contains('road')) {
        type = 'damage';
      } else if (post.category.name.toLowerCase().contains('weather')) {
        type = 'weather';
      } else if (post.category.name.toLowerCase().contains('traffic')) {
        type = 'traffic';
      }

      riskPoints.add(
        RiskPoint(
          location: location,
          level: level,
          description: post.content.length > 50
              ? '${post.content.substring(0, 50)}...'
              : post.content,
          type: type,
          timestamp: post.createdAt,
          radiusMeters: level == NavRiskLevel.critical ? 500.0 : 200.0,
        ),
      );
    }

    return riskPoints;
  }

  // Generate a single route with risk consideration
  Future<NavigationRoute> _generateRoute({
    required LatLng origin,
    required LatLng destination,
    required RouteType type,
    required List<RiskPoint> riskPoints,
    required double avoidanceWeight,
    required int routeVariant,
  }) async {
    // Fetch real road route from OSRM
    final polyline = await _generatePolyline(
      origin,
      destination,
      riskPoints,
      avoidanceWeight,
      routeVariant,
    );
    final segments = _generateSegments(polyline, riskPoints);

    final totalDistance = _calculateTotalDistance(polyline);
    final totalDuration = _calculateDuration(
      totalDistance,
      riskPoints,
      polyline,
    );
    final safetyScore = _calculateSafetyScore(polyline, riskPoints);
    final routeRiskPoints = _getRiskPointsNearRoute(polyline, riskPoints);
    final tollPrice = _estimateTollPrice(totalDistance, type);

    String summary;
    switch (type) {
      case RouteType.fastest:
        summary = 'Fastest route • ${routeRiskPoints.length} risk points';
        break;
      case RouteType.safest:
        summary = 'Safest route • Avoids high-risk areas';
        break;
      case RouteType.balanced:
        summary = 'Balanced route • Good mix of speed and safety';
        break;
    }

    if (tollPrice > 0) {
      summary += ' • Est. toll: RM${tollPrice.toStringAsFixed(2)}';
    }

    return NavigationRoute(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      polyline: polyline,
      segments: segments,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      type: type,
      safetyScore: safetyScore,
      riskPoints: routeRiskPoints,
      summary: summary,
      estimatedTollPrice: tollPrice,
    );
  }

  // Generate polyline using real road network
  Future<List<LatLng>> _generatePolyline(
    LatLng origin,
    LatLng destination,
    List<RiskPoint> riskPoints,
    double avoidanceWeight,
    int routeVariant,
  ) async {
    print(
      'Generating route from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}',
    );

    try {
      // Get waypoints to avoid high-risk areas and create route variations
      final avoidPoints = <LatLng>[];

      if (avoidanceWeight > 0.3) {
        // For safer routes, add waypoints to avoid critical/high risks
        final criticalRisks = riskPoints
            .where(
              (r) =>
                  r.level == NavRiskLevel.critical ||
                  r.level == NavRiskLevel.high,
            )
            .toList();

        // Add waypoints based on route variant to create different paths
        final numWaypoints = avoidanceWeight > 0.7
            ? 3
            : (avoidanceWeight > 0.4 ? 2 : 1);
        for (final risk in criticalRisks.take(numWaypoints)) {
          // Create waypoint offset from risk location with variant offset
          avoidPoints.add(
            _getAvoidanceWaypoint(
              origin,
              destination,
              risk.location,
              routeVariant,
            ),
          );
        }
      }

      // Add route variant waypoint for different paths even without risks
      if (routeVariant > 0 && avoidPoints.isEmpty) {
        // Create alternative path by adding offset waypoint
        final midLat = (origin.latitude + destination.latitude) / 2;
        final midLon = (origin.longitude + destination.longitude) / 2;
        final offset = routeVariant == 1 ? 0.01 : -0.01;
        avoidPoints.add(LatLng(midLat + offset, midLon + offset * 0.5));
      }

      // Build coordinates array: origin -> avoidance points -> destination
      final coordinates = <List<double>>[
        [origin.longitude, origin.latitude], // ORS uses [lon, lat] format
        ...avoidPoints.map((p) => [p.longitude, p.latitude]),
        [destination.longitude, destination.latitude],
      ];

      print('Requesting route with ${coordinates.length} waypoints');

      // Build OSRM URL: lon1,lat1;lon2,lat2;...
      final coordsString = coordinates
          .map((coord) => '${coord[0]},${coord[1]}')
          .join(';');

      final url =
          '$_osrmBaseUrl/$coordsString?overview=full&geometries=geojson';

      print('OSRM URL: $url');

      // Call OSRM API (no auth needed!)
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('OSRM Response code: ${data['code']}');

        if (data['code'] != 'Ok' ||
            data['routes'] == null ||
            (data['routes'] as List).isEmpty) {
          print('No routes found in OSRM response');
          return _fallbackPolyline(origin, destination);
        }

        final route = data['routes'][0];
        final geometry = route['geometry'];

        // OSRM returns GeoJSON geometry with coordinates array
        if (geometry['coordinates'] != null) {
          final coordinates = geometry['coordinates'] as List;
          print('Route has ${coordinates.length} coordinate points');
          final decoded = _decodePolyline(coordinates);

          if (decoded.isEmpty) {
            print('Decoded polyline is empty, using fallback');
            return _fallbackPolyline(origin, destination);
          }

          print(
            '✅ Successfully decoded ${decoded.length} route points following real roads!',
          );
          return decoded;
        } else {
          print('No coordinates in geometry');
          return _fallbackPolyline(origin, destination);
        }
      } else {
        print('OSRM API error: ${response.statusCode}');
        print('Response body: ${response.body}');
        return _fallbackPolyline(origin, destination);
      }
    } catch (e, stackTrace) {
      print('Error fetching route from OSRM: $e');
      print('Stack trace: $stackTrace');
      // Fallback to simple polyline
      return _fallbackPolyline(origin, destination);
    }
  }

  // Calculate waypoint to avoid a risk location
  LatLng _getAvoidanceWaypoint(
    LatLng origin,
    LatLng destination,
    LatLng risk,
    int variant,
  ) {
    // Find midpoint between origin and destination
    final midLat = (origin.latitude + destination.latitude) / 2;
    final midLon = (origin.longitude + destination.longitude) / 2;

    // Calculate perpendicular offset from risk with variant modifier
    final dx = destination.longitude - origin.longitude;
    final dy = destination.latitude - origin.latitude;
    final variantModifier = variant == 0 ? 1.0 : (variant == 1 ? 1.5 : 0.7);
    final perpLon =
        -dy * 0.01 * variantModifier; // 90 degree rotation with variant
    final perpLat = dx * 0.01 * variantModifier;

    return LatLng(midLat + perpLat, midLon + perpLon);
  }

  // Decode ORS geometry coordinates to LatLng list
  List<LatLng> _decodePolyline(List<dynamic> coordinates) {
    try {
      final result = coordinates
          .map((coord) {
            if (coord is List && coord.length >= 2) {
              return LatLng(
                (coord[1] as num).toDouble(), // latitude
                (coord[0] as num).toDouble(), // longitude
              );
            }
            return null;
          })
          .whereType<LatLng>()
          .toList();

      print(
        'Decoded ${result.length} points from ${coordinates.length} coordinates',
      );
      return result;
    } catch (e) {
      print('Error decoding polyline: $e');
      return [];
    }
  }

  // Fallback to simple straight line if API fails
  List<LatLng> _fallbackPolyline(LatLng origin, LatLng destination) {
    print('Using fallback polyline (straight line)');
    final polyline = <LatLng>[origin];
    final steps = 10;
    final latStep = (destination.latitude - origin.latitude) / steps;
    final lonStep = (destination.longitude - origin.longitude) / steps;

    for (int i = 1; i < steps; i++) {
      polyline.add(
        LatLng(
          origin.latitude + (latStep * i),
          origin.longitude + (lonStep * i),
        ),
      );
    }

    polyline.add(destination);
    return polyline;
  }

  // Generate turn-by-turn segments
  List<RouteSegment> _generateSegments(
    List<LatLng> polyline,
    List<RiskPoint> riskPoints,
  ) {
    final segments = <RouteSegment>[];

    for (int i = 0; i < polyline.length - 1; i++) {
      final start = polyline[i];
      final end = polyline[i + 1];
      final distance = _calculateDistance(start, end);
      final duration = (distance / (_averageSpeedKmh * 1000 / 3600));

      // Find risks in this segment
      final segmentRisks = riskPoints.where((risk) {
        return risk.isNearRoute(start, 200.0) || risk.isNearRoute(end, 200.0);
      }).toList();

      String instruction;
      if (i == 0) {
        instruction = 'Start heading towards destination';
      } else if (i == polyline.length - 2) {
        instruction = 'Arrive at destination';
      } else {
        final bearing = _calculateBearing(start, end);
        instruction = _getDirectionInstruction(bearing, distance);
      }

      segments.add(
        RouteSegment(
          start: start,
          end: end,
          distance: distance,
          duration: duration,
          riskPoints: segmentRisks,
          instruction: instruction,
        ),
      );
    }

    return segments;
  }

  String _getDirectionInstruction(double bearing, double distance) {
    String direction;
    if (bearing >= 337.5 || bearing < 22.5) {
      direction = 'north';
    } else if (bearing >= 22.5 && bearing < 67.5) {
      direction = 'northeast';
    } else if (bearing >= 67.5 && bearing < 112.5) {
      direction = 'east';
    } else if (bearing >= 112.5 && bearing < 157.5) {
      direction = 'southeast';
    } else if (bearing >= 157.5 && bearing < 202.5) {
      direction = 'south';
    } else if (bearing >= 202.5 && bearing < 247.5) {
      direction = 'southwest';
    } else if (bearing >= 247.5 && bearing < 292.5) {
      direction = 'west';
    } else {
      direction = 'northwest';
    }

    final distanceKm = (distance / 1000).toStringAsFixed(1);
    return 'Continue $direction for $distanceKm km';
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = atan2(y, x) * 180 / pi;

    return (bearing + 360) % 360;
  }

  double _calculateTotalDistance(List<LatLng> polyline) {
    double total = 0;
    for (int i = 0; i < polyline.length - 1; i++) {
      total += _calculateDistance(polyline[i], polyline[i + 1]);
    }
    return total;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }

  double _calculateDuration(
    double distance,
    List<RiskPoint> riskPoints,
    List<LatLng> polyline,
  ) {
    // Base duration on average speed
    double duration = distance / (_averageSpeedKmh * 1000 / 3600);

    // Add delays for risk points
    final routeRisks = _getRiskPointsNearRoute(polyline, riskPoints);
    for (final risk in routeRisks) {
      switch (risk.level) {
        case NavRiskLevel.critical:
          duration += 300; // 5 minutes delay
          break;
        case NavRiskLevel.high:
          duration += 180; // 3 minutes delay
          break;
        case NavRiskLevel.medium:
          duration += 60; // 1 minute delay
          break;
        case NavRiskLevel.low:
          duration += 0;
          break;
      }
    }

    return duration;
  }

  // Calculate safety score (0-100)
  double _calculateSafetyScore(
    List<LatLng> polyline,
    List<RiskPoint> riskPoints,
  ) {
    double score = 100.0;

    final routeRisks = _getRiskPointsNearRoute(polyline, riskPoints);

    for (final risk in routeRisks) {
      // Deduct points based on risk level
      switch (risk.level) {
        case NavRiskLevel.critical:
          score -= 25;
          break;
        case NavRiskLevel.high:
          score -= 15;
          break;
        case NavRiskLevel.medium:
          score -= 5;
          break;
        case NavRiskLevel.low:
          score -= 2;
          break;
      }
    }

    return score.clamp(0.0, 100.0);
  }

  List<RiskPoint> _getRiskPointsNearRoute(
    List<LatLng> polyline,
    List<RiskPoint> riskPoints,
  ) {
    final nearbyRisks = <RiskPoint>[];

    for (final risk in riskPoints) {
      for (final point in polyline) {
        if (risk.isNearRoute(point, 300.0)) {
          nearbyRisks.add(risk);
          break;
        }
      }
    }

    return nearbyRisks;
  }

  // Estimate toll price based on distance and route type (Malaysia estimates)
  double _estimateTollPrice(double distanceMeters, RouteType type) {
    final distanceKm = distanceMeters / 1000;

    // Rough estimates for Malaysian highways
    // Fastest routes likely use highways more
    if (distanceKm < 10) return 0.0; // Short trips usually no toll

    double baseRate = 0.0;
    switch (type) {
      case RouteType.fastest:
        baseRate = 0.15; // RM per km on highways
        break;
      case RouteType.safest:
        baseRate = 0.08; // Avoids some toll roads
        break;
      case RouteType.balanced:
        baseRate = 0.12; // Mixed roads
        break;
    }

    final estimatedToll = (distanceKm * baseRate).clamp(
      0.0,
      50.0,
    ); // Cap at RM50
    return double.parse(estimatedToll.toStringAsFixed(2));
  }

  // Check if vehicle is off route
  bool isOffRoute(
    Position currentPosition,
    List<LatLng> routePolyline, {
    double thresholdMeters = 100.0,
  }) {
    final currentLatLng = LatLng(
      currentPosition.latitude,
      currentPosition.longitude,
    );

    for (final point in routePolyline) {
      if (_calculateDistance(currentLatLng, point) <= thresholdMeters) {
        return false;
      }
    }

    return true;
  }

  // Get next instruction based on current position
  RouteSegment? getNextSegment(
    Position currentPosition,
    List<RouteSegment> segments,
  ) {
    final currentLatLng = LatLng(
      currentPosition.latitude,
      currentPosition.longitude,
    );

    for (final segment in segments) {
      final distanceToStart = _calculateDistance(currentLatLng, segment.start);
      if (distanceToStart <= 500.0) {
        return segment;
      }
    }

    return segments.isNotEmpty ? segments.first : null;
  }
}
