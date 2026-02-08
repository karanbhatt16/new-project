import 'package:flutter/material.dart';

import '../../auth/firebase_auth_controller.dart';
import '../../call/voice_call_controller.dart';
import '../../chat/e2ee_chat_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../notifications/firestore_notifications_controller.dart';
import '../../posts/firestore_posts_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_error_view.dart';
import '_post_widgets.dart';
import 'create_post_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({
    super.key,
    required this.currentUid,
    required this.posts,
    this.auth,
    this.social,
    this.chat,
    this.e2eeChat,
    this.notifications,
    this.callController,
  });

  final String currentUid;
  final FirestorePostsController posts;
  final FirebaseAuthController? auth;
  final FirestoreSocialGraphController? social;
  final FirestoreChatController? chat;
  final E2eeChatController? e2eeChat;
  final FirestoreNotificationsController? notifications;
  final VoiceCallController? callController;

  @override
  State<FeedPage> createState() => FeedPageState();
}

class FeedPageState extends State<FeedPage> {
  final ScrollController _scrollController = ScrollController();

  /// Scrolls to the top of the feed with animation
  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    // The stream will automatically update, but we add a small delay
    // to show the refresh indicator properly
    await Future.delayed(const Duration(milliseconds: 500));
    // Force rebuild by calling setState
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Get bottom padding to account for bottom nav bar
    final bottomNavBarHeight = MediaQuery.of(context).padding.bottom + 16;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomNavBarHeight),
        child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreatePostPage(
                    currentUid: widget.currentUid,
                    posts: widget.posts,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Create Post',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
      body: StreamBuilder(
        stream: widget.posts.postsStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return AsyncErrorView(error: snap.error!);
          }
          
          // Show skeleton loading while waiting for data
          if (!snap.hasData) {
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: 3, // Show 3 skeleton cards
              itemBuilder: (context, index) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: PostCardSkeleton(),
                );
              },
            );
          }

          final items = snap.data!;
          if (items.isEmpty) {
            return _buildEmptyState(theme, isDark, context);
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surface,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              cacheExtent: 800, // Cache more items for smoother scrolling
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PostCard(
                    post: items[index],
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
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.dynamic_feed_rounded,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No posts yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share something with the campus!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreatePostPage(
                      currentUid: widget.currentUid,
                      posts: widget.posts,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create First Post'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
