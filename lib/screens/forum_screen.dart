import 'package:flutter/cupertino.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/district.dart';
import '../models/post.dart';
import '../models/post_category.dart';
import '../models/user.dart';
import '../models/ad.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';
import '../services/premium_service.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';

class ForumScreen extends StatefulWidget {
  final District district;
  final User? currentUser;

  const ForumScreen({super.key, required this.district, this.currentUser});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AdService _adService = AdService();
  final PremiumService _premiumService = PremiumService();
  bool _isPremiumUser = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    if (widget.currentUser != null) {
      final isPremium = await _premiumService.isPremiumUser(widget.currentUser!.id);
      if (mounted) {
        setState(() => _isPremiumUser = isPremium);
      }
    }
  }

  void _navigateToCreatePost(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => CreatePostScreen(
          district: widget.district,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _navigateToPostDetail(BuildContext context, Post post) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => PostDetailScreen(
          post: post,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _handleAdClick(Ad ad) async {
    await _adService.recordClick(ad.id);
    if (mounted) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text(ad.merchantName),
          message: Column(
            children: [
              if (ad.imageUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ad.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(ad.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 8),
              Text(ad.content),
              if (ad.merchantAddress != null) ...[
                const SizedBox(height: 8),
                Text('📍 ${ad.merchantAddress}'),
              ],
              if (ad.merchantPhone != null) ...[
                const SizedBox(height: 4),
                Text('📞 ${ad.merchantPhone}'),
              ],
            ],
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('View Details'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text('${widget.district.name} Forum'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add_circled),
          onPressed: () => _navigateToCreatePost(context),
        ),
      ),
      child: StreamBuilder<List<Post>>(
        stream: _firebaseService.getPostsStream(widget.district.id),
        builder: (context, snapshot) {
          print('Stream state: ${snapshot.connectionState}');
          print('Has data: ${snapshot.hasData}');
          print('Has error: ${snapshot.hasError}');

          if (snapshot.hasError) {
            print('Stream error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    size: 80,
                    color: CupertinoColors.systemRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading posts',
                    style: const TextStyle(
                      fontSize: 18,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }

          if (!snapshot.hasData) {
            print('No data in snapshot');
            return const Center(child: CupertinoActivityIndicator());
          }

          final posts = snapshot.data!;
          print('Posts loaded: ${posts.length}');

          // Separate sponsored and regular posts
          final sponsoredPosts = posts.where((p) => p.isSponsored).toList();
          final regularPosts = posts.where((p) => !p.isSponsored).toList();
          
          return FutureBuilder<List<Ad>>(
            // Use district center coordinates for ad filtering
            future: _adService.getNearbyAds(
              widget.district.latitude,
              widget.district.longitude,
              type: AdType.forumPost,
              districtId: widget.district.id,
            ),
            builder: (context, adSnapshot) {
              print('═══════════════════════════════════════════');
              print('ForumScreen: Loading forum ads for ${widget.district.name}');
              print('ForumScreen: District ID: ${widget.district.id}');
              print('ForumScreen: District coords: (${widget.district.latitude}, ${widget.district.longitude})');
              print('ForumScreen: Connection state: ${adSnapshot.connectionState}');
              print('ForumScreen: Has error: ${adSnapshot.hasError}');
              if (adSnapshot.hasError) {
                print('ForumScreen: Error: ${adSnapshot.error}');
              }
              final forumAds = adSnapshot.data ?? [];
              print('ForumScreen: Found ${forumAds.length} forum ads');
              if (forumAds.isEmpty) {
                print('ForumScreen: ⚠️ NO ADS FOUND - Check:');
                print('  1. Ad type is AdType.forumPost');
                print('  2. Ad districtId matches: ${widget.district.id}');
                print('  3. Ad status is "active"');
                print('  4. Ad location is within district');
              } else {
                for (var ad in forumAds) {
                  print('ForumScreen: ✓ Ad: ${ad.title} (${ad.merchantName})');
                  print('  - Status: ${ad.status.name}');
                  print('  - District: ${ad.districtId}');
                  print('  - Location: (${ad.latitude}, ${ad.longitude})');
                }
              }
              print('ForumScreen: Premium user: $_isPremiumUser');
              print('═══════════════════════════════════════════');
              
              return CustomScrollView(
                slivers: [
                  // Sponsored ads at top (if not premium)
                  if (!_isPremiumUser && forumAds.isNotEmpty)
                    SliverSafeArea(
                      bottom: false,
                      sliver: SliverPadding(
                        padding: const EdgeInsets.only(top: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final ad = forumAds[index];
                              return _SponsoredAdCard(
                                ad: ad,
                                onTap: () => _handleAdClick(ad),
                                onImpression: () => _adService.recordImpression(ad.id),
                              );
                            },
                            childCount: forumAds.length > 2 ? 2 : forumAds.length,
                          ),
                        ),
                      ),
                    ),
                  
                  // Sponsored posts (if not premium)
                  if (!_isPremiumUser && sponsoredPosts.isNotEmpty)
                    SliverSafeArea(
                      bottom: false,
                      sliver: SliverPadding(
                        padding: const EdgeInsets.only(top: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final post = sponsoredPosts[index];
                              return _PostCard(
                                post: post,
                                onTap: () => _navigateToPostDetail(context, post),
                                isSponsored: true,
                              );
                            },
                            childCount: sponsoredPosts.length,
                          ),
                        ),
                      ),
                    ),
                  
                  // Regular posts
                  SliverSafeArea(
                    bottom: false,
                    sliver: SliverPadding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final post = regularPosts[index];
                            return _PostCard(
                              post: post,
                              onTap: () => _navigateToPostDetail(context, post),
                              isSponsored: false,
                            );
                          },
                          childCount: regularPosts.length,
                        ),
                      ),
                    ),
                  ),
              
              if (sponsoredPosts.isEmpty && regularPosts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyForumState(
                    districtId: widget.district.id,
                    onCreatePost: () => _navigateToCreatePost(context),
                  ),
                ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SponsoredAdCard extends StatefulWidget {
  final Ad ad;
  final VoidCallback onTap;
  final VoidCallback onImpression;

  const _SponsoredAdCard({
    required this.ad,
    required this.onTap,
    required this.onImpression,
  });

  @override
  State<_SponsoredAdCard> createState() => _SponsoredAdCardState();
}

class _EmptyForumState extends StatelessWidget {
  final String districtId;
  final VoidCallback onCreatePost;

  const _EmptyForumState({
    required this.districtId,
    required this.onCreatePost,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.chat_bubble_2,
            size: 80,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 18,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'District: $districtId',
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.systemGrey2,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            child: const Text('Create First Post'),
            onPressed: onCreatePost,
          ),
        ],
      ),
    );
  }
}

class _SponsoredAdCardState extends State<_SponsoredAdCard> {
  @override
  void initState() {
    super.initState();
    // Record impression when card is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onImpression();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF007AFF).withOpacity(0.05),
              const Color(0xFF5856D6).withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF007AFF).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          CupertinoIcons.tag_fill,
                          size: 12,
                          color: Color(0xFF007AFF),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Sponsored',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (widget.ad.logoUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.ad.logoUrl!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(CupertinoIcons.building_2_fill, size: 24),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.ad.merchantName,
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.ad.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.ad.content,
                style: const TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.ad.imageUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.ad.imageUrl!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  final bool isSponsored;

  const _PostCard({
    required this.post,
    required this.onTap,
    this.isSponsored = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    if (isSponsored)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SPONSORED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                        ),
                      ),
                    if (post.isPinned && !isSponsored)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          CupertinoIcons.pin_fill,
                          size: 14,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: post.category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            post.category.icon,
                            size: 13,
                            color: post.category.color,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            post.category.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: post.category.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeago.format(post.createdAt),
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Title
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Content
                Text(
                  post.content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.secondaryLabel,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                // Media Preview
                if (post.mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: post.mediaUrls.first,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: CupertinoColors.systemGrey6,
                        height: 180,
                        child: const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: CupertinoColors.systemGrey6,
                        height: 180,
                        child: const Icon(
                          CupertinoIcons.photo,
                          color: CupertinoColors.tertiaryLabel,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Footer
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.person_circle,
                      size: 16,
                      color: CupertinoColors.secondaryLabel,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      post.username,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      CupertinoIcons.heart,
                      size: 16,
                      color: CupertinoColors.secondaryLabel,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.likeCount}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      CupertinoIcons.chat_bubble,
                      size: 16,
                      color: CupertinoColors.secondaryLabel,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentCount}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
