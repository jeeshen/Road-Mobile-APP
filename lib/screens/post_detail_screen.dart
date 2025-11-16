import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/post_category.dart';
import '../services/firebase_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final String _currentUserId = 'demo_user'; // TODO: Replace with actual user ID
  Post? _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _loadPostUpdates();
  }

  void _loadPostUpdates() {
    _firebaseService.getPostsStream(widget.post.districtId).listen((posts) {
      final updatedPost = posts.firstWhere(
        (p) => p.id == widget.post.id,
        orElse: () => widget.post,
      );
      if (mounted) {
        setState(() {
          _currentPost = updatedPost;
        });
      }
    });
  }

  Future<void> _toggleLike() async {
    if (_currentPost == null) return;

    try {
      await _firebaseService.toggleLike(_currentPost!.id, _currentUserId);
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Failed to update like: $e'),
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

  @override
  void dispose() {
    _commentController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    final comment = Comment(
      id: const Uuid().v4(),
      postId: widget.post.id,
      userId: 'demo_user',
      username: _usernameController.text.isEmpty
          ? 'Anonymous'
          : _usernameController.text,
      content: _commentController.text,
      createdAt: DateTime.now(),
    );

    try {
      await _firebaseService.createComment(comment);
      if (!mounted) return;
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Failed to add comment: $e'),
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Post Details'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Post Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: widget.post.category.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.post.category.icon,
                                  size: 14,
                                  color: widget.post.category.color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.post.category.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.post.category.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Title
                          Text(
                            widget.post.title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Meta Info
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.person_circle,
                                size: 16,
                                color: CupertinoColors.secondaryLabel,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.post.username,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Icon(
                                CupertinoIcons.time,
                                size: 16,
                                color: CupertinoColors.secondaryLabel,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                timeago.format(widget.post.createdAt),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Like and Comment Actions
                          Row(
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minSize: 0,
                                onPressed: _toggleLike,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      (_currentPost?.likedBy.contains(_currentUserId) ?? false)
                                          ? CupertinoIcons.heart_fill
                                          : CupertinoIcons.heart,
                                      color: (_currentPost?.likedBy.contains(_currentUserId) ?? false)
                                          ? CupertinoColors.systemRed
                                          : CupertinoColors.secondaryLabel,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_currentPost?.likeCount ?? widget.post.likeCount}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: (_currentPost?.likedBy.contains(_currentUserId) ?? false)
                                            ? CupertinoColors.systemRed
                                            : CupertinoColors.secondaryLabel,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    CupertinoIcons.chat_bubble,
                                    size: 20,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_currentPost?.commentCount ?? widget.post.commentCount}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: CupertinoColors.secondaryLabel,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Content
                          Text(
                            widget.post.content,
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.4,
                              letterSpacing: -0.2,
                            ),
                          ),
                          // Media
                          if (widget.post.mediaUrls.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            ...widget.post.mediaUrls.map((url) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      height: 200,
                                      color: CupertinoColors.systemGrey6,
                                      child: const Center(
                                        child: CupertinoActivityIndicator(),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                          const SizedBox(height: 24),
                          // Comments Header
                          Text(
                            'Comments',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  // Comments List
                  StreamBuilder<List<Comment>>(
                    stream: _firebaseService.getCommentsStream(widget.post.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        print('Comments stream error: ${snapshot.error}');
                        return SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(
                                    CupertinoIcons.exclamationmark_triangle,
                                    size: 48,
                                    color: CupertinoColors.systemRed,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Error loading comments',
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: CupertinoColors.secondaryLabel,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: CupertinoColors.tertiaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CupertinoActivityIndicator()),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CupertinoActivityIndicator()),
                          ),
                        );
                      }

                      final comments = snapshot.data!;
                      if (comments.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    CupertinoIcons.chat_bubble_2,
                                    size: 48,
                                    color: CupertinoColors.tertiaryLabel,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No comments yet',
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: CupertinoColors.secondaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final comment = comments[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemBackground,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.systemGrey6,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.person_fill,
                                            size: 18,
                                            color: CupertinoColors.secondaryLabel,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                comment.username,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                timeago.format(comment.createdAt),
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
                                    const SizedBox(height: 10),
                                    Text(
                                      comment.content,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            childCount: comments.length,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Comment Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                border: Border(
                  top: BorderSide(
                    color: CupertinoColors.separator.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CupertinoTextField(
                        controller: _usernameController,
                        placeholder: 'Username (Optional)',
                        padding: const EdgeInsets.all(8),
                        decoration: null,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: CupertinoTextField(
                              controller: _commentController,
                              placeholder: 'Add a comment...',
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                              maxLines: null,
                              decoration: null,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 0,
                          onPressed: _addComment,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: CupertinoColors.systemBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.arrow_up,
                              size: 18,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ],
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

