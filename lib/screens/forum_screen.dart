import 'package:flutter/cupertino.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/district.dart';
import '../models/post.dart';
import '../models/post_category.dart';
import '../services/firebase_service.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';

class ForumScreen extends StatelessWidget {
  final District district;
  final FirebaseService _firebaseService = FirebaseService();

  ForumScreen({super.key, required this.district});

  void _navigateToCreatePost(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => CreatePostScreen(district: district),
      ),
    );
  }

  void _navigateToPostDetail(BuildContext context, Post post) {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (context) => PostDetailScreen(post: post)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text('${district.name} Forum'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add_circled),
          onPressed: () => _navigateToCreatePost(context),
        ),
      ),
      child: StreamBuilder<List<Post>>(
        stream: _firebaseService.getPostsStream(district.id),
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

          if (posts.isEmpty) {
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
                    'District: ${district.id}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton(
                    child: const Text('Create First Post'),
                    onPressed: () => _navigateToCreatePost(context),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final post = posts[index];
                      return _PostCard(
                        post: post,
                        onTap: () => _navigateToPostDetail(context, post),
                      );
                    }, childCount: posts.length),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const _PostCard({required this.post, required this.onTap});

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
                    if (post.isPinned)
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
