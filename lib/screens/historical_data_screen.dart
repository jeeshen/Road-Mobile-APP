import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../models/post.dart';
import '../models/district.dart';
import '../services/analytics_service.dart';

class HistoricalDataScreen extends StatelessWidget {
  final List<Post> posts;
  final List<District> districts;

  const HistoricalDataScreen({
    super.key,
    required this.posts,
    required this.districts,
  });

  @override
  Widget build(BuildContext context) {
    final analyticsService = AnalyticsService();
    final weeklyAccidents = analyticsService.getWeeklyAccidentCount(posts);
    final congestedRoads = analyticsService.getMostCongestedRoads(posts);
    final routeSafety = analyticsService.getRouteSafetyRatings(posts, districts);

    final sortedWeeklyAccidents = weeklyAccidents.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Historical Data'),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Weekly Accident Count
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Weekly Accident Count',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: CupertinoColors.secondaryLabel,
                          letterSpacing: -0.08,
                        ),
                      ),
                    ),
                    if (sortedWeeklyAccidents.isEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.info_circle,
                              size: 20,
                              color: CupertinoColors.secondaryLabel,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'No accident data available',
                              style: TextStyle(
                                fontSize: 15,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      CupertinoListSection.insetGrouped(
                        children: sortedWeeklyAccidents
                            .take(8)
                            .map((entry) {
                              return CupertinoListTile(
                                title: Text(
                                  'Week of ${DateFormat('MMM d, yyyy').format(entry.key)}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemRed
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${entry.value}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.systemRed,
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            // Most Congested Roads
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Most Congested Roads',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: CupertinoColors.secondaryLabel,
                          letterSpacing: -0.08,
                        ),
                      ),
                    ),
                    if (congestedRoads.isEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.info_circle,
                              size: 20,
                              color: CupertinoColors.secondaryLabel,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'No congestion data available',
                              style: TextStyle(
                                fontSize: 15,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      CupertinoListSection.insetGrouped(
                        children: congestedRoads.asMap().entries.map((entry) {
                          final index = entry.key;
                          final road = entry.value;
                          final district = districts.firstWhere(
                            (d) => d.id == road.districtId,
                            orElse: () => districts.first,
                          );
                          return CupertinoListTile(
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: index < 3
                                    ? CupertinoColors.systemOrange
                                    : CupertinoColors.systemGrey5,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: index < 3
                                        ? CupertinoColors.white
                                        : CupertinoColors.label,
                                  ),
                                ),
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
                              '${road.count} report${road.count == 1 ? '' : 's'} • ${DateFormat('MMM d').format(road.lastReport)}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            // Route Safety Ratings - Safest Routes
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.checkmark_shield_fill,
                            size: 16,
                            color: CupertinoColors.systemGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Safest Routes',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: CupertinoColors.secondaryLabel,
                              letterSpacing: -0.08,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoListSection.insetGrouped(
                      children: routeSafety.take(5).map((route) {
                        return CupertinoListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGreen
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              size: 18,
                              color: CupertinoColors.systemGreen,
                            ),
                          ),
                          title: Text(
                            route.districtName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          subtitle: Text(
                            '${route.totalIncidents} incident${route.totalIncidents == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGreen
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${route.safetyScore.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.systemGreen,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            // Route Safety Ratings - Most Dangerous Routes
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            size: 16,
                            color: CupertinoColors.systemRed,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Most Dangerous Routes',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: CupertinoColors.secondaryLabel,
                              letterSpacing: -0.08,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoListSection.insetGrouped(
                      children: routeSafety.reversed.take(5).map((route) {
                        return CupertinoListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemRed
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              size: 18,
                              color: CupertinoColors.systemRed,
                            ),
                          ),
                          title: Text(
                            route.districtName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          subtitle: Text(
                            '${route.accidents} accident${route.accidents == 1 ? '' : 's'}, ${route.trafficJams} jam${route.trafficJams == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemRed
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${route.safetyScore.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.systemRed,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

