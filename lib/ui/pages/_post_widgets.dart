import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../auth/firebase_auth_controller.dart';
import '../../call/voice_call_controller.dart';
import '../../chat/e2ee_chat_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../notifications/firestore_notifications_controller.dart';
import '../../posts/firestore_posts_controller.dart';
import '../../posts/post_models.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';
import '../widgets/cached_avatar.dart';
import '../widgets/skeleton_widgets.dart';
import 'post_image_widget.dart';
import 'user_profile_page.dart';

export '../widgets/skeleton_widgets.dart' show PostCardSkeleton, CommentSkeleton;

/// Post card with optimistic like updates
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.currentUid,
    required this.posts,
    this.auth,
    this.social,
    this.chat,
    this.e2eeChat,
    this.notifications,
    this.callController,
  });

  final Post post;
  final String currentUid;
  final FirestorePostsController posts;
  final FirebaseAuthController? auth;
  final FirestoreSocialGraphController? social;
  final FirestoreChatController? chat;
  final E2eeChatController? e2eeChat;
  final FirestoreNotificationsController? notifications;
  final VoiceCallController? callController;

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

  Future<void> _openUserProfile(BuildContext context, String uid) async {
    // Don't open profile if auth/social controllers are not available
    if (widget.auth == null || widget.social == null) return;
    
    // Don't navigate to own profile from posts
    if (uid == widget.currentUid) return;

    final user = await widget.auth!.publicProfileByUid(uid);
    if (user == null || !context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          currentUserUid: widget.currentUid,
          user: user,
          social: widget.social!,
          auth: widget.auth,
          chat: widget.chat,
          e2eeChat: widget.e2eeChat,
          notifications: widget.notifications,
          callController: widget.callController,
        ),
      ),
    );
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

                List<int>? avatarBytes;
                final b64 = data?['profileImageB64'] as String?;
                if (b64 != null && b64.isNotEmpty) {
                  try {
                    avatarBytes = base64Decode(b64);
                  } catch (_) {
                    avatarBytes = null;
                  }
                }

                return Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openUserProfile(context, widget.post.createdByUid),
                      child: CachedAvatar(
                        imageBytes: avatarBytes,
                        radius: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openUserProfile(context, widget.post.createdByUid),
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
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
        auth: widget.auth,
        social: widget.social,
        chat: widget.chat,
        e2eeChat: widget.e2eeChat,
        notifications: widget.notifications,
        callController: widget.callController,
      ),
    );
  }

  Future<void> _showReportDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _ReportDialog(
          onReport: (reason, details) {
            Navigator.of(dialogContext).pop();
            fireAndForget(
              runAsyncAction(
                context,
                () => widget.posts.reportPost(
                  postId: widget.post.id,
                  reportedByUid: widget.currentUid,
                  reason: reason,
                  details: details,
                ),
                successMessage: 'Reported',
              ),
            );
          },
        );
      },
    );
  }
}

/// Stateful dialog for reporting posts - handles its own TextEditingController lifecycle
class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.onReport});

  final void Function(String reason, String? details) onReport;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _reasons = <String>['HARASSMENT', 'NUDITY', 'OTHER'];
  late String _selected;
  late TextEditingController _detailsController;

  @override
  void initState() {
    super.initState();
    _selected = _reasons.first;
    _detailsController = TextEditingController();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report post'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selected,
            items: [for (final r in _reasons) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => setState(() => _selected = v ?? _reasons.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsController,
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
            final details = _detailsController.text.trim();
            widget.onReport(_selected, details.isEmpty ? null : details);
          },
          child: const Text('Report'),
        ),
      ],
    );
  }
}

/// Bottom sheet for displaying and adding comments.
class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.post,
    required this.currentUid,
    required this.posts,
    this.auth,
    this.social,
    this.chat,
    this.e2eeChat,
    this.notifications,
    this.callController,
  });

  final Post post;
  final String currentUid;
  final FirestorePostsController posts;
  final FirebaseAuthController? auth;
  final FirestoreSocialGraphController? social;
  final FirestoreChatController? chat;
  final E2eeChatController? e2eeChat;
  final FirestoreNotificationsController? notifications;
  final VoiceCallController? callController;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;
  bool _showEmojiPicker = false;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _commentController.text;
    final selection = _commentController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji.emoji,
    );
    _commentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.emoji.length,
      ),
    );
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() => _showEmojiPicker = !_showEmojiPicker);
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate max height based on keyboard visibility
    // When keyboard is open, we need less height for the sheet
    final keyboardOpen = bottomInset > 0;
    final maxSheetHeight = keyboardOpen 
        ? screenHeight - bottomInset - MediaQuery.of(context).padding.top - 50
        : screenHeight * 0.7;

    return Padding(
      // Add padding at the bottom when keyboard is visible
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
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
                      auth: widget.auth,
                      social: widget.social,
                      chat: widget.chat,
                      e2eeChat: widget.e2eeChat,
                      notifications: widget.notifications,
                      callController: widget.callController,
                    );
                  },
                );
              },
            ),
          ),

          // Emoji picker (shown above input when active)
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: _onEmojiSelected,
                config: Config(
                  height: 250,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 8,
                    emojiSizeMax: 28,
                    verticalSpacing: 0,
                    horizontalSpacing: 0,
                    gridPadding: EdgeInsets.zero,
                    backgroundColor: theme.colorScheme.surface,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    initCategory: Category.SMILEYS,
                    backgroundColor: theme.colorScheme.surface,
                    indicatorColor: theme.colorScheme.primary,
                    iconColorSelected: theme.colorScheme.primary,
                    iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    enabled: false,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: theme.colorScheme.surface,
                    buttonIconColor: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),

          // Comment input
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + (keyboardOpen ? 0 : bottomPadding)),
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
                // Emoji button
                IconButton(
                  onPressed: _toggleEmojiPicker,
                  icon: Icon(
                    _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: _showEmojiPicker 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  tooltip: _showEmojiPicker ? 'Show keyboard' : 'Add emoji',
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    onTap: () {
                      if (_showEmojiPicker) {
                        setState(() => _showEmojiPicker = false);
                      }
                    },
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
                        ? const SizedBox(
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
    this.auth,
    this.social,
    this.chat,
    this.e2eeChat,
    this.notifications,
    this.callController,
  });

  final Comment comment;
  final String currentUid;
  final FirestorePostsController posts;
  final String timeAgo;
  final FirebaseAuthController? auth;
  final FirestoreSocialGraphController? social;
  final FirestoreChatController? chat;
  final E2eeChatController? e2eeChat;
  final FirestoreNotificationsController? notifications;
  final VoiceCallController? callController;

  Future<void> _openUserProfile(BuildContext context, String uid) async {
    if (auth == null || social == null) return;
    if (uid == currentUid) return;

    final user = await auth!.publicProfileByUid(uid);
    if (user == null || !context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          currentUserUid: currentUid,
          user: user,
          social: social!,
          auth: auth,
          chat: chat,
          e2eeChat: e2eeChat,
          notifications: notifications,
          callController: callController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = comment.authorUid == currentUid;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(comment.authorUid).get(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final username = (data?['username'] as String?) ?? 'Unknown';

        List<int>? avatarBytes;
        final b64 = data?['profileImageB64'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          try {
            avatarBytes = base64Decode(b64);
          } catch (_) {
            avatarBytes = null;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _openUserProfile(context, comment.authorUid),
                child: CachedAvatar(
                  imageBytes: avatarBytes,
                  radius: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _openUserProfile(context, comment.authorUid),
                          child: Text(
                            username,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
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
