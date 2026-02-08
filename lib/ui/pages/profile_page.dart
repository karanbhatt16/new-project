import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../call/voice_call_controller.dart';
import '../../chat/e2ee_chat_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../notifications/firestore_notifications_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../../posts/firestore_posts_controller.dart';
import '../../posts/post_models.dart';
import '../../preferences/theme_preferences.dart';
import '../../vibeu_app.dart';
import '../widgets/async_action.dart';
import '../widgets/cached_avatar.dart';
import '_post_widgets.dart';
import 'edit_profile_page.dart';
import 'friends_list_page.dart';
import 'match_history_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.signedInUid,
    required this.signedInEmail,
    required this.onSignOut,
    required this.auth,
    required this.social,
    required this.posts,
    this.chat,
    this.e2eeChat,
    this.notifications,
    this.callController,
  });

  final String signedInUid;
  final String signedInEmail;
  final VoidCallback onSignOut;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;
  final FirestorePostsController posts;
  final FirestoreChatController? chat;
  final E2eeChatController? e2eeChat;
  final FirestoreNotificationsController? notifications;
  final VoiceCallController? callController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder(
      stream: auth.profileStreamByUid(signedInUid),
      builder: (context, snapshot) {
        final me = snapshot.data;

        return Container(
          color: theme.colorScheme.surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              // Profile Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.surfaceContainerLow,
                      theme.colorScheme.surfaceContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar with edit button
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => runAsyncAction(context, () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (result == null || result.files.isEmpty) return;
                            final bytes = result.files.single.bytes;
                            if (bytes == null) return;
                            await auth.updateProfileImage(uid: signedInUid, bytes: bytes);
                          }),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.surface,
                              ),
                              padding: const EdgeInsets.all(3),
                              child: CachedAvatar(
                                imageBytes: me?.profileImageBytes,
                                radius: 45,
                                fallbackIconSize: 50,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Username
                    Text(
                      me?.username.isNotEmpty == true ? me!.username : 'Your Profile',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Email
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        signedInEmail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionButton(
                          icon: Icons.edit_rounded,
                          label: 'Edit',
                          onTap: me != null ? () => _navigateToEditProfile(context, me) : null,
                          theme: theme,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          icon: Icons.photo_camera_rounded,
                          label: 'Photo',
                          onTap: () => runAsyncAction(context, () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (result == null || result.files.isEmpty) return;
                            final bytes = result.files.single.bytes;
                            if (bytes == null) return;
                            await auth.updateProfileImage(uid: signedInUid, bytes: bytes);
                          }),
                          theme: theme,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          icon: Icons.logout_rounded,
                          label: 'Logout',
                          onTap: onSignOut,
                          theme: theme,
                          isDark: isDark,
                          isDestructive: true,
                        ),
                      ],
                    ),
                    
                    if (me?.bio.isEmpty ?? true) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              color: Colors.amber[700],
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Add a bio and interests to get more matches!',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.amber[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

            _SectionCard(
              title: 'Friends',
              child: StreamBuilder<Set<String>>(
                stream: social.friendsStream(uid: signedInUid),
                builder: (context, snap) {
                  final count = snap.data?.length;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FriendsListPage(
                            signedInUid: signedInUid,
                            auth: auth,
                            social: social,
                            chat: chat,
                            e2eeChat: e2eeChat,
                            notifications: notifications,
                            callController: callController,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.group_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              count == null ? '… friends' : '$count friends',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Match/Relationship Section
            _SectionCard(
              title: 'Relationship',
              child: StreamBuilder<Match?>(
                stream: social.currentMatchStream(uid: signedInUid),
                builder: (context, matchSnap) {
                  final currentMatch = matchSnap.data;
                  final isMatched = currentMatch != null && currentMatch.isActive;

                  if (isMatched) {
                    final partnerUid = currentMatch.otherUid(signedInUid);
                    return FutureBuilder<AppUser?>(
                      future: auth.publicProfileByUid(partnerUid),
                      builder: (context, partnerSnap) {
                        final partner = partnerSnap.data;
                        final partnerName = partner?.username ?? 'Loading...';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Current match display
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.pink.shade50,
                                    Colors.red.shade50,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.pink.shade200),
                              ),
                              child: Row(
                                children: [
                                  CachedAvatar(
                                    imageBytes: partner?.profileImageBytes,
                                    radius: 24,
                                    backgroundColor: Colors.pink.shade100,
                                    fallbackIcon: Icons.favorite,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'In a relationship with',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.pink.shade700,
                                          ),
                                        ),
                                        Text(
                                          partnerName,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.favorite, color: Colors.pink),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _confirmBreakUp(context, partnerName),
                                    icon: const Icon(Icons.heart_broken, size: 18),
                                    label: const Text('Break Up'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => _navigateToMatchHistory(context, me),
                                    icon: const Icon(Icons.history, size: 18),
                                    label: const Text('History'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  }

                  // Not matched - show single status
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.favorite_border,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Single',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => _navigateToMatchHistory(context, me),
                        icon: const Icon(Icons.history),
                        label: const Text('View Match History'),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'About',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (me?.bio.isNotEmpty ?? false) ...[
                    Text(
                      me!.bio,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Icon(
                        _genderIcon(me?.gender),
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        me?.gender.label ?? 'Not specified',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (me?.interests.isNotEmpty ?? false) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final interest in me!.interests)
                          Chip(
                            label: Text(interest),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                  if ((me?.bio.isEmpty ?? true) && (me?.interests.isEmpty ?? true)) ...[
                    Text(
                      'No bio or interests yet. Tap "Edit profile" to add them!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'Your posts',
              child: StreamBuilder<List<Post>>(
                stream: posts.userPostsStream(uid: signedInUid),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text('Failed to load posts: ${snap.error}');
                  }
                  if (!snap.hasData) {
                    return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                  }

                  final items = snap.data!;
                  if (items.isEmpty) {
                    return const Text('No posts yet. Create one from the Feed tab.');
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${items.length} post${items.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _MyPostsPage(
                                  posts: posts,
                                  signedInUid: signedInUid,
                                  auth: auth,
                                  social: social,
                                  chat: chat,
                                  e2eeChat: e2eeChat,
                                  notifications: notifications,
                                  callController: callController,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.article_outlined),
                          label: const Text('View all posts'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'Appearance',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how VibeU looks to you. Select a theme preference below.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  ListenableBuilder(
                    listenable: VibeUApp.themePreferences,
                    builder: (context, _) {
                      final currentMode = VibeUApp.themePreferences.themeMode;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppThemeMode.values.map((mode) {
                          final isSelected = currentMode == mode;
                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ThemePreferences.getIcon(mode),
                                  size: 18,
                                  color: isSelected 
                                      ? theme.colorScheme.onSecondaryContainer
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(ThemePreferences.getDisplayName(mode)),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                VibeUApp.themePreferences.setThemeMode(mode);
                              }
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'Account',
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ),
            ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required ThemeData theme,
    required bool isDark,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : theme.colorScheme.primary;
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEditProfile(BuildContext context, AppUser user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          currentUser: user,
          auth: auth,
        ),
      ),
    );
  }

  void _navigateToMatchHistory(BuildContext context, AppUser? user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchHistoryPage(
          profileUid: signedInUid,
          profileUsername: user?.username ?? 'You',
          currentUserUid: signedInUid,
          auth: auth,
          social: social,
          isOwnProfile: true,
        ),
      ),
    );
  }

  Future<void> _confirmBreakUp(BuildContext context, String partnerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Break Up?'),
        content: Text(
          'Are you sure you want to break up with $partnerName? '
          'This will end your relationship and everyone will be able to see it in your match history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Break Up'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await runAsyncAction(
        context,
        () => social.breakMatch(uid: signedInUid),
        successMessage: 'Relationship ended',
      );
    }
  }

  IconData _genderIcon(Gender? gender) {
    return switch (gender) {
      Gender.male => Icons.male,
      Gender.female => Icons.female,
      Gender.nonBinary => Icons.transgender,
      Gender.preferNotToSay => Icons.person_outline,
      null => Icons.person_outline,
    };
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Page to display all posts by the current user in a feed-like layout (like LinkedIn)
class _MyPostsPage extends StatelessWidget {
  const _MyPostsPage({
    required this.posts,
    required this.signedInUid,
    this.auth,
    this.social,
    this.chat,
    this.e2eeChat,
    this.notifications,
    this.callController,
  });

  final FirestorePostsController posts;
  final String signedInUid;
  final FirebaseAuthController? auth;
  final FirestoreSocialGraphController? social;
  final FirestoreChatController? chat;
  final E2eeChatController? e2eeChat;
  final FirestoreNotificationsController? notifications;
  final VoiceCallController? callController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Posts'),
      ),
      body: StreamBuilder<List<Post>>(
        stream: posts.userPostsStream(uid: signedInUid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load posts: ${snap.error}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            );
          }

          if (!snap.hasData) {
            // Skeleton loading
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: 3,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: PostCardSkeleton(),
              ),
            );
          }

          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No posts yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first post from the Feed tab',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PostCard(
                  post: items[index],
                  currentUid: signedInUid,
                  posts: posts,
                  auth: auth,
                  social: social,
                  chat: chat,
                  e2eeChat: e2eeChat,
                  notifications: notifications,
                  callController: callController,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
