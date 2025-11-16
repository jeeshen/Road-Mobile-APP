import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/district.dart';
import '../services/analytics_service.dart' hide RiskLevel;
import '../services/chatgpt_service.dart';
import '../models/post.dart' show Post;

class HistoricalDataScreen extends StatefulWidget {
  final List<Post> posts;
  final List<District> districts;

  const HistoricalDataScreen({
    super.key,
    required this.posts,
    required this.districts,
  });

  @override
  State<HistoricalDataScreen> createState() => _HistoricalDataScreenState();
}

class _HistoricalDataScreenState extends State<HistoricalDataScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final ChatGPTService? _chatGPTService = ChatGPTService(
    apiKey:
        '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',
  );
  String? _todaySummary;
  bool _isLoadingTodaySummary = false;

  @override
  void initState() {
    super.initState();
    _loadTodaySummary();
  }

  Future<void> _loadTodaySummary() async {
    if (_chatGPTService == null) return;

    setState(() {
      _isLoadingTodaySummary = true;
    });

    try {
      final summary = await _chatGPTService.generateTodayTrafficSummary(
        widget.posts,
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

  @override
  Widget build(BuildContext context) {
    final weeklyAccidents = _analyticsService.getWeeklyAccidentCount(widget.posts);
    final congestedRoads = _analyticsService.getMostCongestedRoads(widget.posts);
    final routeSafety = _analyticsService.getRouteSafetyRatings(widget.posts, widget.districts);

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
            // Today's Summary Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: CupertinoListSection.insetGrouped(
                  header: const SizedBox.shrink(),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
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
                            const CupertinoActivityIndicator(radius: 8)
                          else if (_todaySummary != null) ...[
                            Text(
                              _todaySummary!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.label,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final todayData = _analyticsService
                                    .getTodayTrafficData(widget.posts);
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
                              'Loading...',
                              style: TextStyle(
                                fontSize: 12,
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
                          final district = widget.districts.firstWhere(
                            (d) => d.id == road.districtId,
                            orElse: () => widget.districts.first,
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

