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

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Historical Data'),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Weekly Accident Count
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weekly Accident Count',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (weeklyAccidents.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'No accident data available',
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      )
                    else
                      ...(weeklyAccidents.entries.toList()
                        ..sort((a, b) => b.key.compareTo(a.key)))
                        .take(8)
                        .map((entry) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: CupertinoColors.separator,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Week of ${DateFormat('MMM d, yyyy').format(entry.key)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemRed
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${entry.value} accident${entry.value == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.systemRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ],
                ),
              ),
            ),
            // Most Congested Roads
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Most Congested Roads',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (congestedRoads.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'No congestion data available',
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      )
                    else
                      ...congestedRoads.asMap().entries.map((entry) {
                        final index = entry.key;
                        final road = entry.value;
                        final district = districts.firstWhere(
                          (d) => d.id == road.districtId,
                          orElse: () => districts.first,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: CupertinoColors.separator,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: index < 3
                                      ? CupertinoColors.systemOrange
                                      : CupertinoColors.systemGrey5,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: index < 3
                                          ? CupertinoColors.white
                                          : CupertinoColors.label,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      district.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${road.count} report${road.count == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: CupertinoColors.secondaryLabel,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                DateFormat('MMM d').format(road.lastReport),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.tertiaryLabel,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
            // Route Safety Ratings
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Route Safety Ratings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Safest Routes
                    const Text(
                      'Safest Routes',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...routeSafety.take(5).map((route) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: CupertinoColors.separator,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    route.districtName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${route.totalIncidents} incident${route.totalIncidents == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: CupertinoColors.secondaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGreen
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${route.safetyScore.toStringAsFixed(0)}/100',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.systemGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 20),
                    // Most Dangerous Routes
                    const Text(
                      'Most Dangerous Routes',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...routeSafety.reversed.take(5).map((route) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: CupertinoColors.separator,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    route.districtName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${route.accidents} accident${route.accidents == 1 ? '' : 's'}, ${route.trafficJams} jam${route.trafficJams == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: CupertinoColors.secondaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemRed
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${route.safetyScore.toStringAsFixed(0)}/100',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.systemRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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

