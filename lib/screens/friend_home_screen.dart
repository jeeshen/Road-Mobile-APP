import 'package:characters/characters.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/district.dart';
import '../models/post.dart';
import '../models/post_category.dart';
import '../models/user.dart';
import '../services/firebase_service.dart';
import '../services/friend_service.dart';
import 'post_detail_screen.dart';

class FriendHomeScreen extends StatefulWidget {
  final User currentUser;
  final String friendId;
  final String friendName;

  const FriendHomeScreen({
    super.key,
    required this.currentUser,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<FriendHomeScreen> createState() => _FriendHomeScreenState();
}

class _FriendHomeScreenState extends State<FriendHomeScreen> {
  final FriendService _friendService = FriendService();
  final FirebaseService _firebaseService = FirebaseService();
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  User? _friendUser;
  bool _isProfileLoading = true;
  String? _profileError;

  Map<String, District> _districtsById = {};
  bool _isDistrictsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriendProfile();
    _loadDistricts();
  }

  Future<void> _loadFriendProfile() async {
    setState(() {
      _isProfileLoading = true;
      _profileError = null;
    });
    try {
      final friend = await _friendService.getUserById(widget.friendId);
      if (!mounted) return;
      setState(() {
        _friendUser = friend;
        _isProfileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileError = 'Unable to load profile';
        _isProfileLoading = false;
      });
    }
  }

  Future<void> _loadDistricts() async {
    setState(() {
      _isDistrictsLoading = true;
    });
    try {
      final districts = await _firebaseService.getDistricts();
      if (!mounted) return;
      setState(() {
        _districtsById = {
          for (final district in districts) district.id: district,
        };
        _isDistrictsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _districtsById = {};
        _isDistrictsLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([_loadFriendProfile(), _loadDistricts()]);
  }

  void _openPostDetail(Post post) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) =>
            PostDetailScreen(post: post, currentUser: widget.currentUser),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _friendUser?.name.isNotEmpty == true
        ? _friendUser!.name
        : widget.friendName;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CupertinoScrollbar(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(displayName.isEmpty ? 'Friend' : displayName),
            ),
            CupertinoSliverRefreshControl(onRefresh: _handleRefresh),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildProfileCard(displayName),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _buildActivityHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                child: _buildPostsSection(),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(String displayName) {
    if (_isProfileLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration,
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_profileError != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration,
        child: Column(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: CupertinoColors.systemRed,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              _profileError!,
              style: const TextStyle(
                fontSize: 15,
                color: CupertinoColors.systemRed,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              onPressed: _loadFriendProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final friend = _friendUser;
    final avatarLetter = displayName.isNotEmpty
        ? displayName.characters.first.toUpperCase()
        : '?';
    final memberSince = friend?.createdAt != null
        ? _dateFormat.format(friend!.createdAt)
        : 'Unknown';
    final characterLabel = (friend?.selectedCharacter ?? 'Not selected')
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    avatarLetter,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.systemBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'User ID: ${widget.friendId}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Member since $memberSince',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _ProfilePill(
                    label: 'Character',
                    value: characterLabel,
                    icon: CupertinoIcons.game_controller_solid,
                  ),
                ),
                const SizedBox(width: 12),
                _LocationStatusIndicator(
                  isEnabled: friend?.shareLocation ?? false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Forum Activity',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        if (_isDistrictsLoading)
          const CupertinoActivityIndicator()
        else
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _handleRefresh,
            child: const Icon(CupertinoIcons.refresh_circled),
          ),
      ],
    );
  }

  Widget _buildPostsSection() {
    return StreamBuilder<List<Post>>(
      stream: _firebaseService.getUserPostsStream(widget.friendId, limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_circle,
                  size: 42,
                  color: CupertinoColors.systemRed,
                ),
                const SizedBox(height: 12),
                Text(
                  'Could not load posts.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  onPressed: _handleRefresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              children: const [
                Icon(
                  CupertinoIcons.tickets,
                  size: 48,
                  color: CupertinoColors.secondaryLabel,
                ),
                SizedBox(height: 12),
                Text(
                  'No posts yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text(
                  'This friend has not posted in any forum.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
              ],
            ),
          );
        }

        final stats = _calculateStats(posts);
        final groupedPosts = _groupPostsByDistrict(posts);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildStatsRow(stats),
            ),
            ...groupedPosts.entries.map((entry) {
              final districtName =
                  _districtsById[entry.key]?.name ?? 'Forum ${entry.key}';
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$districtName • ${entry.value.length} posts',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...entry.value.map(
                      (post) => _FriendPostTile(
                        post: post,
                        districtName: districtName,
                        onTap: () => _openPostDetail(post),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Map<String, dynamic> _calculateStats(List<Post> posts) {
    final totalLikes = posts.fold<int>(0, (sum, post) => sum + post.likeCount);
    final totalComments = posts.fold<int>(
      0,
      (sum, post) => sum + post.commentCount,
    );
    final latestPost = posts.first.createdAt;

    return {
      'posts': posts.length,
      'likes': totalLikes,
      'comments': totalComments,
      'latest': latestPost,
    };
  }

  Map<String, List<Post>> _groupPostsByDistrict(List<Post> posts) {
    final map = <String, List<Post>>{};
    for (final post in posts) {
      map.putIfAbsent(post.districtId, () => []).add(post);
    }
    for (final entry in map.entries) {
      entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final sortedKeys = map.keys.toList()
      ..sort(
        (a, b) => map[b]!.first.createdAt.compareTo(map[a]!.first.createdAt),
      );
    return {for (final key in sortedKeys) key: map[key]!};
  }

  Widget _buildStatsRow(Map<String, dynamic> stats) {
    return IntrinsicHeight(
      child: Row(
        children: [
          _StatsChip(
            label: 'Posts',
            value: stats['posts'].toString(),
            icon: CupertinoIcons.doc_plaintext,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ReactionsChip(
              likes: stats['likes'],
              comments: stats['comments'],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: CupertinoColors.systemBackground,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: CupertinoColors.black.withOpacity(0.05),
        blurRadius: 30,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

class _LocationStatusIndicator extends StatelessWidget {
  final bool isEnabled;

  const _LocationStatusIndicator({required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    final color = isEnabled
        ? CupertinoColors.systemGreen
        : CupertinoColors.secondaryLabel;
    final icon = isEnabled
        ? CupertinoIcons.location_solid
        : CupertinoIcons.location_slash;

    return Semantics(
      label: isEnabled
          ? 'Location sharing enabled'
          : 'Location sharing disabled',
      child: Container(
        width: 56,
        height: double.infinity,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfilePill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: CupertinoColors.systemGrey),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatsChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatsChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: CupertinoColors.systemGrey),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionsChip extends StatelessWidget {
  final int likes;
  final int comments;

  const _ReactionsChip({
    required this.likes,
    required this.comments,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                CupertinoIcons.heart_circle_fill,
                size: 18,
                color: CupertinoColors.systemGrey,
              ),
              SizedBox(width: 6),
              Text(
                'Reactions',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ReactionStatPill(
                icon: CupertinoIcons.heart_fill,
                label: '$likes Likes',
              ),
              _ReactionStatPill(
                icon: CupertinoIcons.text_bubble_fill,
                label: '$comments Comments',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionStatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ReactionStatPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: CupertinoColors.secondaryLabel,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendPostTile extends StatelessWidget {
  final Post post;
  final String districtName;
  final VoidCallback onTap;

  const _FriendPostTile({
    required this.post,
    required this.districtName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = post.category;
    final relativeTime = timeago.format(post.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(24),
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withOpacity(0.05),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(category.icon, size: 14, color: category.color),
                        const SizedBox(width: 6),
                        Text(
                          category.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            color: category.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    relativeTime,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              if (post.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  post.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.location_solid,
                    size: 16,
                    color: CupertinoColors.systemGrey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      districtName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: CupertinoColors.systemGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _PostStat(
                    icon: CupertinoIcons.heart_fill,
                    value: post.likeCount.toString(),
                  ),
                  const SizedBox(width: 10),
                  _PostStat(
                    icon: CupertinoIcons.text_bubble_fill,
                    value: post.commentCount.toString(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostStat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _PostStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: CupertinoColors.secondaryLabel),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}
