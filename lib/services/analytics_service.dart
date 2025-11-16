import '../models/post.dart';
import '../models/district.dart';
import '../models/post_category.dart';

class AnalyticsService {
  // Get post count per district
  Map<String, int> getPostCountsByDistrict(List<Post> posts) {
    final Map<String, int> counts = {};
    for (var post in posts) {
      counts[post.districtId] = (counts[post.districtId] ?? 0) + 1;
    }
    return counts;
  }

  // Get current emergencies (accidents, roadblocks, road closures)
  List<Post> getCurrentEmergencies(List<Post> posts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return posts.where((post) {
      final isEmergency = post.category == PostCategory.accident ||
          post.category == PostCategory.roadblock ||
          post.category == PostCategory.roadClosure;
      
      final postDate = DateTime(
        post.createdAt.year,
        post.createdAt.month,
        post.createdAt.day,
      );
      
      return isEmergency && postDate.isAtSameMomentAs(today);
    }).toList();
  }

  // Calculate user attention heatmap data
  Map<String, double> calculateHeatmapData(List<Post> posts) {
    final Map<String, double> heatmap = {};
    
    for (var post in posts) {
      final key = post.districtId;
      final weight = _calculatePostWeight(post);
      heatmap[key] = (heatmap[key] ?? 0.0) + weight;
    }
    
    return heatmap;
  }

  double _calculatePostWeight(Post post) {
    double weight = 1.0;
    
    // Emergency posts get higher weight
    if (post.category == PostCategory.accident) weight *= 3.0;
    if (post.category == PostCategory.roadblock) weight *= 2.5;
    if (post.category == PostCategory.roadClosure) weight *= 2.5;
    
    // Recent posts get higher weight
    final hoursSincePost = DateTime.now().difference(post.createdAt).inHours;
    if (hoursSincePost < 1) weight *= 2.0;
    else if (hoursSincePost < 6) weight *= 1.5;
    else if (hoursSincePost < 24) weight *= 1.2;
    
    // Engagement boosts weight
    weight += (post.commentCount * 0.1);
    weight += (post.likeCount * 0.05);
    
    return weight;
  }

  // Get today's traffic summary data
  TodayTrafficData getTodayTrafficData(List<Post> posts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final todayPosts = posts.where((post) {
      final postDate = DateTime(
        post.createdAt.year,
        post.createdAt.month,
        post.createdAt.day,
      );
      return postDate.isAtSameMomentAs(today);
    }).toList();

    final accidents = todayPosts
        .where((p) => p.category == PostCategory.accident)
        .length;
    final trafficJams = todayPosts
        .where((p) => p.category == PostCategory.trafficJam)
        .length;
    final roadblocks = todayPosts
        .where((p) => p.category == PostCategory.roadblock)
        .length;
    final roadClosures = todayPosts
        .where((p) => p.category == PostCategory.roadClosure)
        .length;

    final riskLevel = _calculateRiskLevel(
      accidents,
      trafficJams,
      roadblocks,
      roadClosures,
    );

    return TodayTrafficData(
      totalPosts: todayPosts.length,
      accidents: accidents,
      trafficJams: trafficJams,
      roadblocks: roadblocks,
      roadClosures: roadClosures,
      riskLevel: riskLevel,
      posts: todayPosts,
    );
  }

  RiskLevel _calculateRiskLevel(
    int accidents,
    int trafficJams,
    int roadblocks,
    int roadClosures,
  ) {
    int score = 0;
    
    score += accidents * 10;
    score += roadblocks * 5;
    score += roadClosures * 5;
    score += trafficJams * 2;
    
    if (score >= 30) return RiskLevel.critical;
    if (score >= 20) return RiskLevel.high;
    if (score >= 10) return RiskLevel.medium;
    return RiskLevel.low;
  }

  // Get weekly accident count
  Map<DateTime, int> getWeeklyAccidentCount(List<Post> posts) {
    final Map<DateTime, int> weeklyCounts = {};
    
    final accidentPosts = posts
        .where((p) => p.category == PostCategory.accident)
        .toList();
    
    for (var post in accidentPosts) {
      final postDate = DateTime(
        post.createdAt.year,
        post.createdAt.month,
        post.createdAt.day,
      );
      
      // Get start of week (Monday)
      final weekday = postDate.weekday;
      final startOfWeek = postDate.subtract(Duration(days: weekday - 1));
      final weekStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      
      weeklyCounts[weekStart] = (weeklyCounts[weekStart] ?? 0) + 1;
    }
    
    return weeklyCounts;
  }

  // Get most congested roads (by traffic jam posts)
  List<RoadCongestion> getMostCongestedRoads(List<Post> posts) {
    final Map<String, RoadCongestion> roadData = {};
    
    final trafficJamPosts = posts
        .where((p) => p.category == PostCategory.trafficJam)
        .toList();
    
    for (var post in trafficJamPosts) {
      // Use district as road identifier (can be enhanced with actual road names)
      final roadId = post.districtId;
      
      if (!roadData.containsKey(roadId)) {
        roadData[roadId] = RoadCongestion(
          roadId: roadId,
          districtId: post.districtId,
          count: 0,
          lastReport: post.createdAt,
        );
      }
      
      final road = roadData[roadId]!;
      roadData[roadId] = RoadCongestion(
        roadId: road.roadId,
        districtId: road.districtId,
        count: road.count + 1,
        lastReport: post.createdAt.isAfter(road.lastReport)
            ? post.createdAt
            : road.lastReport,
      );
    }
    
    final sorted = roadData.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    
    return sorted.take(10).toList();
  }

  // Calculate safety ratings for routes
  List<RouteSafety> getRouteSafetyRatings(
    List<Post> posts,
    List<District> districts,
  ) {
    final Map<String, RouteSafety> routeData = {};
    
    for (var district in districts) {
      final districtPosts = posts
          .where((p) => p.districtId == district.id)
          .toList();
      
      int accidents = 0;
      int trafficJams = 0;
      int roadblocks = 0;
      int roadClosures = 0;
      int totalPosts = districtPosts.length;
      
      for (var post in districtPosts) {
        switch (post.category) {
          case PostCategory.accident:
            accidents++;
            break;
          case PostCategory.trafficJam:
            trafficJams++;
            break;
          case PostCategory.roadblock:
            roadblocks++;
            break;
          case PostCategory.roadClosure:
            roadClosures++;
            break;
          default:
            break;
        }
      }
      
      final safetyScore = _calculateSafetyScore(
        accidents,
        trafficJams,
        roadblocks,
        roadClosures,
        totalPosts,
      );
      
      routeData[district.id] = RouteSafety(
        districtId: district.id,
        districtName: district.name,
        safetyScore: safetyScore,
        accidents: accidents,
        trafficJams: trafficJams,
        roadblocks: roadblocks,
        roadClosures: roadClosures,
        totalIncidents: totalPosts,
      );
    }
    
    final sorted = routeData.values.toList()
      ..sort((a, b) => a.safetyScore.compareTo(b.safetyScore));
    
    return sorted;
  }

  double _calculateSafetyScore(
    int accidents,
    int trafficJams,
    int roadblocks,
    int roadClosures,
    int totalPosts,
  ) {
    if (totalPosts == 0) return 100.0; // No incidents = safest
    
    double score = 100.0;
    
    // Deduct points for incidents
    score -= (accidents * 15);
    score -= (roadblocks * 8);
    score -= (roadClosures * 8);
    score -= (trafficJams * 3);
    
    // Normalize to 0-100 range
    return score.clamp(0.0, 100.0);
  }
}

class TodayTrafficData {
  final int totalPosts;
  final int accidents;
  final int trafficJams;
  final int roadblocks;
  final int roadClosures;
  final RiskLevel riskLevel;
  final List<Post> posts;

  TodayTrafficData({
    required this.totalPosts,
    required this.accidents,
    required this.trafficJams,
    required this.roadblocks,
    required this.roadClosures,
    required this.riskLevel,
    required this.posts,
  });
}

enum RiskLevel {
  low,
  medium,
  high,
  critical,
}

extension RiskLevelExtension on RiskLevel {
  String get displayName {
    switch (this) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
      case RiskLevel.critical:
        return 'Critical';
    }
  }

  int get colorValue {
    switch (this) {
      case RiskLevel.low:
        return 0xFF34C759; // Green
      case RiskLevel.medium:
        return 0xFFFFCC00; // Yellow
      case RiskLevel.high:
        return 0xFFFF9500; // Orange
      case RiskLevel.critical:
        return 0xFFFF3B30; // Red
    }
  }
}

class RoadCongestion {
  final String roadId;
  final String districtId;
  final int count;
  final DateTime lastReport;

  RoadCongestion({
    required this.roadId,
    required this.districtId,
    required this.count,
    required this.lastReport,
  });
}

class RouteSafety {
  final String districtId;
  final String districtName;
  final double safetyScore;
  final int accidents;
  final int trafficJams;
  final int roadblocks;
  final int roadClosures;
  final int totalIncidents;

  RouteSafety({
    required this.districtId,
    required this.districtName,
    required this.safetyScore,
    required this.accidents,
    required this.trafficJams,
    required this.roadblocks,
    required this.roadClosures,
    required this.totalIncidents,
  });
}

