import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../posts/firestore_posts_controller.dart';
import '../../posts/post_models.dart';
import '../widgets/async_action.dart';
import '../widgets/skeleton_widgets.dart';
import 'post_image_widget.dart';

export '../widgets/skeleton_widgets.dart' show PostCardSkeleton, CommentSkeleton;

/// Post card with optimistic like updates
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.currentUid,
    required this.posts,
  });

  final Post post;
  final String currentUid;
  final FirestorePostsController posts;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  // Optimistic state for likes
  bool? _optimisticLiked;
  int? _optimisticLikeCount;
  bool _isLikeInProgress = false;

  /// Check if the post has an image (either imageUrl or imagePath)
  bool get _hasImage {
    final post = widget.post;
    return (post.imageUrl != null && post.imageUrl!.isNotEmpty) ||
           (post.imagePath != null && post.imagePath!.isNotEmpty);
  }

  void _handleLikeTap(bool currentLiked) async {
    if (_isLikeInProgress) return;

    // Optimistic update - immediately update UI
    setState(() {
      _isLikeInProgress = true;
      _optimisticLiked = !currentLiked;
      _optimisticLikeCount = (_optimisticLikeCount ?? widget.post.likeCount) + (currentLiked ? -1 : 1);
      if (_optimisticLikeCount! < 0) _optimisticLikeCount = 0;
    });

    try {
      // Fire and forget - don't wait for server response
      widget.posts.toggleLike(postId: widget.post.id, uid: widget.currentUid).catchError((e) {
        // Revert on error
        if (mounted) {
          setState(() {
            _optimisticLiked = null;
            _optimisticLikeCount = null;
          });
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLikeInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.post.createdByUid).snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data();
                final username = (data?['username'] as String?) ?? 'Unknown';

                MemoryImage? avatar;
                final b64 = data?['profileImageB64'] as String?;
                if (b64 != null && b64.isNotEmpty) {
                  try {
                    avatar = MemoryImage(base64Decode(b64));
                  } catch (_) {
                    avatar = null;
                  }
                }

                final initial = (username.isNotEmpty ? username.substring(0, 1) : '?').toUpperCase();

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: avatar,
                      child: avatar == null ? Text(initial) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (widget.post.createdByUid == widget.currentUid)
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => runAsyncAction(
                          context,
                          () => widget.posts.deletePost(postId: widget.post.id, requesterUid: widget.currentUid),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                );
              },
            ),
            if (_hasImage) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: PostImage(post: widget.post),
                ),
              ),
            ],
            if (widget.post.caption.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                widget.post.caption,
                style: theme.textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                StreamBuilder<bool>(
                  stream: widget.posts.isLikedStream(postId: widget.post.id, uid: widget.currentUid),
                  builder: (context, snap) {
                    // Use optimistic state if available, otherwise use stream data
                    final serverLiked = snap.data ?? false;
                    final liked = _optimisticLiked ?? serverLiked;
                    
                    // Sync optimistic state when server confirms
                    if (_optimisticLiked != null && snap.hasData && _optimisticLiked == serverLiked) {
                      // Server caught up, clear optimistic state
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _optimisticLiked = null;
                            _optimisticLikeCount = null;
                          });
                        }
                      });
                    }
                    
                    return IconButton(
                      tooltip: liked ? 'Unlike' : 'Like',
                      onPressed: () => _handleLikeTap(liked),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: Icon(
                          liked ? Icons.favorite : Icons.favorite_border,
                          key: ValueKey(liked),
                        ),
                      ),
                      color: liked ? Colors.red : null,
                    );
                  },
                ),
                // Use optimistic count if available
                Text('${_optimisticLikeCount ?? widget.post.likeCount}'),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Comments',
                  onPressed: () => _showCommentsSheet(context),
                  icon: const Icon(Icons.chat_bubble_outline),
                ),
                Text('${widget.post.commentCount}'),
                const Spacer(),
                IconButton(
                  tooltip: 'Report',
                  onPressed: () => _showReportDialog(context),
                  icon: const Icon(Icons.flag_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsSheet(
        post: widget.post,
        currentUid: widget.currentUid,
        posts: widget.posts,
      ),
    );
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final reasons = <String>['HARASSMENT', 'NUDITY', 'OTHER'];
    String selected = reasons.first;
    final details = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selected,
                items: [for (final r in reasons) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => selected = v ?? reasons.first,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: details,
                decoration: const InputDecoration(labelText: 'Details (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                fireAndForget(
                  runAsyncAction(
                    context,
                    () => widget.posts.reportPost(
                      postId: widget.post.id,
                      reportedByUid: widget.currentUid,
                      reason: selected,
                      details: details.text.trim().isEmpty ? null : details.text.trim(),
                    ),
                    successMessage: 'Reported',
                  ),
                );
              },
              child: const Text('Report'),
            ),
          ],
        );
      },
    ).whenComplete(details.dispose);
  }
}

/// Bottom sheet for displaying and adding comments.
class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.post,
    required this.currentUid,
    required this.posts,
  });

  final Post post;
  final String currentUid;
  final FirestorePostsController posts;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);

    try {
      await widget.posts.addComment(
        postId: widget.post.id,
        authorUid: widget.currentUid,
        text: text,
      );
      _commentController.clear();
      _focusNode.unfocus();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.post.commentCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // Comments list
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: widget.posts.commentsStream(postId: widget.post.id),
              builder: (context, snap) {
                if (!snap.hasData) {
                  // Skeleton loading for comments
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: 4,
                    itemBuilder: (context, index) => const CommentSkeleton(),
                  );
                }

                final comments = snap.data!;
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No comments yet',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Be the first to comment!',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return _CommentTile(
                      comment: comment,
                      currentUid: widget.currentUid,
                      posts: widget.posts,
                      timeAgo: _timeAgo(comment.createdAt),
                    );
                  },
                );
              },
            ),
          ),

          // Comment input
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _submitting ? null : _submitComment,
                    icon: _submitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single comment tile.
class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.currentUid,
    required this.posts,
    required this.timeAgo,
  });

  final Comment comment;
  final String currentUid;
  final FirestorePostsController posts;
  final String timeAgo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = comment.authorUid == currentUid;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(comment.authorUid).get(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final username = (data?['username'] as String?) ?? 'Unknown';

        MemoryImage? avatar;
        final b64 = data?['profileImageB64'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          try {
            avatar = MemoryImage(base64Decode(b64));
          } catch (_) {
            avatar = null;
          }
        }

        final initial = (username.isNotEmpty ? username.substring(0, 1) : '?').toUpperCase();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: avatar,
                child: avatar == null ? Text(initial, style: const TextStyle(fontSize: 14)) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          username,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.text,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (isOwner)
                IconButton(
                  onPressed: () => runAsyncAction(
                    context,
                    () => posts.deleteComment(
                      postId: comment.postId,
                      commentId: comment.id,
                      requesterUid: currentUid,
                    ),
                  ),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: 'Delete',
                ),
            ],
          ),
        );
      },
    );
  }
}
