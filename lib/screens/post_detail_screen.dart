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
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: widget.post.category.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.post.category.icon,
                                  size: 16,
                                  color: widget.post.category.color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.post.category.displayName,
                                  style: TextStyle(
                                    fontSize: 13,
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Meta Info
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.person_circle,
                                size: 16,
                                color: CupertinoColors.systemGrey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.post.username,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Icon(
                                CupertinoIcons.time,
                                size: 16,
                                color: CupertinoColors.systemGrey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                timeago.format(widget.post.createdAt),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Content
                          Text(
                            widget.post.content,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                          // Media
                          if (widget.post.mediaUrls.isNotEmpty) ...[
                            const SizedBox(height: 16),
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
                          Container(
                            height: 0.5,
                            color: CupertinoColors.separator,
                          ),
                          const SizedBox(height: 16),
                          // Comments Header
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.chat_bubble_2,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Comments (${widget.post.commentCount})',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  // Comments List
                  StreamBuilder<List<Comment>>(
                    stream: _firebaseService.getCommentsStream(widget.post.id),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SliverToBoxAdapter(
                          child: Center(child: CupertinoActivityIndicator()),
                        );
                      }

                      final comments = snapshot.data!;
                      if (comments.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'No comments yet',
                                style: TextStyle(
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final comment = comments[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: CupertinoColors.separator,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.person_circle_fill,
                                        size: 20,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        comment.username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        timeago.format(comment.createdAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    comment.content,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: comments.length,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Comment Input
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: CupertinoColors.systemBackground,
                border: Border(
                  top: BorderSide(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  CupertinoTextField(
                    controller: _usernameController,
                    placeholder: 'Username (Optional)',
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _commentController,
                          placeholder: 'Add a comment...',
                          padding: const EdgeInsets.all(12),
                          maxLines: null,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _addComment,
                        child: const Icon(
                          CupertinoIcons.arrow_up_circle_fill,
                          size: 32,
                          color: CupertinoColors.activeBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

