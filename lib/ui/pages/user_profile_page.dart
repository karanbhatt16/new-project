import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/cached_avatar.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../call/voice_call_controller.dart';
import '../../chat/e2ee_chat_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../notifications/firestore_notifications_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';
import 'chat_thread_page.dart';
import 'match_action_button.dart';
import 'match_history_page.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({
    super.key,
    required this.currentUserUid,
    required this.user,
    required this.social,
    this.auth,
    this.chat,
    this.e2eeChat,
    this.notifications,
    this.callController,
    @Deprecated('Use chat controllers instead') this.onMessage,
  });

  final String currentUserUid;
  final AppUser user;
  final FirestoreSocialGraphController social;
  final FirebaseAuthController? auth;
  final FirestoreChatController? chat;
  final E2eeChatController? e2eeChat;
  final FirestoreNotificationsController? notifications;
  final VoiceCallController? callController;
  
  /// Callback to open chat with this user. If null, message button won't be shown.
  @Deprecated('Use chat controllers instead')
  final VoidCallback? onMessage;

  /// Check if we can open chat (all required controllers are available)
  bool get _canOpenChat =>
      auth != null &&
      chat != null &&
      e2eeChat != null &&
      notifications != null &&
      callController != null;

  Future<void> _openChat(BuildContext context) async {
    if (!_canOpenChat) {
      // Fallback to legacy onMessage callback
      // ignore: deprecated_member_use_from_same_package
      onMessage?.call();
      return;
    }

    // Get current user profile
    final currentUser = await auth!.publicProfileByUid(currentUserUid);
    if (currentUser == null || !context.mounted) return;

    // Get or create thread
    final thread = await chat!.getOrCreateThread(
      myUid: currentUserUid,
      myEmail: currentUser.email,
      otherUid: user.uid,
      otherEmail: user.email,
    );

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadPage(
          currentUser: currentUser,
          otherUser: user,
          thread: thread,
          chat: chat!,
          e2eeChat: e2eeChat!,
          social: social,
          notifications: notifications!,
          callController: callController!,
          isMatchChat: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // ignore: deprecated_member_use_from_same_package
    final canMessage = _canOpenChat || onMessage != null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header with profile image
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Large profile avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CachedAvatar(
                          imageBytes: user.profileImageBytes,
                          radius: 60,
                          fallbackIconSize: 60,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Username
                      Text(
                        user.username,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Gender chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.gender.label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Action buttons row (Add Friend / Message)
                _buildActionButtonsSection(context, theme, canMessage),
                const SizedBox(height: 16),
                
                // Bio section
                _buildBioCard(theme, isDark),
                const SizedBox(height: 12),
                
                // Interests section
                if (user.interests.isNotEmpty) ...[
                  _buildInterestsCard(theme),
                  const SizedBox(height: 12),
                ],
                
                // Friends section (only if we're friends)
                StreamBuilder<FriendStatus>(
                  stream: social.friendStatusStream(myUid: currentUserUid, otherUid: user.uid),
                  builder: (context, snap) {
                    final s = snap.data;
                    if (s != null && s.areFriends && auth != null) {
                      return Column(
                        children: [
                          _FriendsSection(
                            currentUserUid: currentUserUid,
                            profileUserUid: user.uid,
                            profileUsername: user.username,
                            social: social,
                            auth: auth!,
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                
                // Match Section - visible to everyone
                if (auth != null)
                  StreamBuilder<AppUser?>(
                    stream: auth!.profileStreamByUid(currentUserUid),
                    builder: (context, currentUserSnap) {
                      return _MatchSection(
                        currentUserUid: currentUserUid,
                        currentUserGender: currentUserSnap.data?.gender,
                        profileUser: user,
                        social: social,
                        auth: auth,
                      );
                    },
                  )
                else
                  _MatchSection(
                    currentUserUid: currentUserUid,
                    currentUserGender: null,
                    profileUser: user,
                    social: social,
                    auth: auth,
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsSection(BuildContext context, ThemeData theme, bool canMessage) {
    return StreamBuilder<List<String>>(
      stream: social.blockedUsersStream(uid: currentUserUid),
      builder: (context, blockedSnap) {
        final blockedUsers = blockedSnap.data ?? [];
        final isBlocked = blockedUsers.contains(user.uid);

        if (isBlocked) {
          return _BlockedUserCard(
            friendUsername: user.username,
            onUnblock: () => social.unblockUser(blockerUid: currentUserUid, blockedUid: user.uid),
          );
        }

        return StreamBuilder<FriendStatus>(
          stream: social.friendStatusStream(myUid: currentUserUid, otherUid: user.uid),
          builder: (context, snap) {
            final s = snap.data;
            if (s == null) {
              return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
            }

            return _ProfileActionButtons(
              status: s,
              friendUsername: user.username,
              canMessage: canMessage,
              onAdd: () => runAsyncAction(
                context,
                () => social.sendRequest(fromUid: currentUserUid, toUid: user.uid),
              ),
              onCancel: () => runAsyncAction(
                context,
                () => social.cancelOutgoing(fromUid: currentUserUid, toUid: user.uid),
              ),
              onAccept: () => runAsyncAction(
                context,
                () => social.acceptIncoming(toUid: currentUserUid, fromUid: user.uid),
              ),
              onDecline: () => runAsyncAction(
                context,
                () => social.declineIncoming(toUid: currentUserUid, fromUid: user.uid),
              ),
              onBlock: () => social.blockUser(blockerUid: currentUserUid, blockedUid: user.uid),
              onMessage: () => _openChat(context),
            );
          },
        );
      },
    );
  }

  Widget _buildBioCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'About',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.bio.isEmpty ? 'No bio yet.' : user.bio,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: user.bio.isEmpty
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                  : theme.colorScheme.onSurface,
              fontStyle: user.bio.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.interests, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Interests',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final interest in user.interests)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    interest,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the friends of the profile user.
class _FriendsSection extends StatelessWidget {
  const _FriendsSection({
    required this.currentUserUid,
    required this.profileUserUid,
    required this.profileUsername,
    required this.social,
    required this.auth,
  });

  final String currentUserUid;
  final String profileUserUid;
  final String profileUsername;
  final FirestoreSocialGraphController social;
  final FirebaseAuthController auth;

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
            Row(
              children: [
                Icon(Icons.people, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  "$profileUsername's Friends",
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Fetch both the profile user's friends AND current user's friends
            FutureBuilder<(Set<String>, Set<String>)>(
              future: () async {
                final results = await Future.wait([
                  social.getFriends(uid: profileUserUid),
                  social.getFriends(uid: currentUserUid),
                ]);
                return (results[0], results[1]);
              }(),
              builder: (context, friendsSnap) {
                if (friendsSnap.hasError) {
                  return Text(
                    'Could not load friends',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  );
                }
                if (!friendsSnap.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                final profileFriendUids = friendsSnap.data!.$1.toList();
                final myFriendUids = friendsSnap.data!.$2;
                
                if (profileFriendUids.isEmpty) {
                  return Text(
                    'No friends yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }

                // Calculate mutual friends (excluding self)
                final mutualFriendUids = profileFriendUids
                    .where((uid) => uid != currentUserUid && myFriendUids.contains(uid))
                    .toSet();

                return FutureBuilder<List<AppUser>>(
                  future: auth.publicProfilesByUids(profileFriendUids),
                  builder: (context, usersSnap) {
                    if (usersSnap.hasError) {
                      return Text(
                        'Could not load friends',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      );
                    }
                    if (!usersSnap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    final friends = usersSnap.data!;
                    
                    // Sort: mutual friends first, then alphabetically
                    friends.sort((a, b) {
                      final aMutual = mutualFriendUids.contains(a.uid);
                      final bMutual = mutualFriendUids.contains(b.uid);
                      if (aMutual && !bMutual) return -1;
                      if (!aMutual && bMutual) return 1;
                      return a.username.toLowerCase().compareTo(b.username.toLowerCase());
                    });

                    // Show max 5 friends, with a "See all" option
                    final displayFriends = friends.take(5).toList();
                    final hasMore = friends.length > 5;

                    return Column(
                      children: [
                        // Show mutual friends count if any
                        if (mutualFriendUids.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_alt_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${mutualFriendUids.length} mutual friend${mutualFriendUids.length > 1 ? 's' : ''}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        for (final friend in displayFriends) ...[
                          _FriendTile(
                            friend: friend,
                            currentUserUid: currentUserUid,
                            social: social,
                            auth: auth,
                            isMutualFriend: mutualFriendUids.contains(friend.uid),
                          ),
                          if (friend != displayFriends.last) const SizedBox(height: 8),
                        ],
                        if (hasMore) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _AllFriendsPage(
                                    currentUserUid: currentUserUid,
                                    profileUsername: profileUsername,
                                    friends: friends,
                                    social: social,
                                    auth: auth,
                                    mutualFriendUids: mutualFriendUids,
                                  ),
                                ),
                              );
                            },
                            child: Text('See all ${friends.length} friends'),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.currentUserUid,
    required this.social,
    required this.auth,
    this.isMutualFriend = false,
  });

  final AppUser friend;
  final String currentUserUid;
  final FirestoreSocialGraphController social;
  final FirebaseAuthController auth;
  final bool isMutualFriend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = friend.uid == currentUserUid;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isMe
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserProfilePage(
                    currentUserUid: currentUserUid,
                    user: friend,
                    social: social,
                    auth: auth,
                  ),
                ),
              );
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            // Avatar with mutual friend indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: friend.profileImageBytes != null
                      ? MemoryImage(Uint8List.fromList(friend.profileImageBytes!))
                      : null,
                  child: friend.profileImageBytes == null
                      ? Text(
                          friend.username.isEmpty ? '?' : friend.username[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )
                      : null,
                ),
                if (isMutualFriend)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.people_alt_rounded,
                        size: 10,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isMe ? '${friend.username} (You)' : friend.username,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isMutualFriend && !isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Mutual',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (friend.bio.isNotEmpty)
                    Text(
                      friend.bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (!isMe)
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// Full page showing all friends of a user.
class _AllFriendsPage extends StatelessWidget {
  const _AllFriendsPage({
    required this.currentUserUid,
    required this.profileUsername,
    required this.friends,
    required this.social,
    required this.auth,
    required this.mutualFriendUids,
  });

  final String currentUserUid;
  final String profileUsername;
  final List<AppUser> friends;
  final FirestoreSocialGraphController social;
  final FirebaseAuthController auth;
  final Set<String> mutualFriendUids;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutualCount = mutualFriendUids.length;
    
    return Scaffold(
      appBar: AppBar(
        title: Text("$profileUsername's Friends"),
      ),
      body: Column(
        children: [
          // Mutual friends summary at top
          if (mutualCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.people_alt_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$mutualCount mutual friend${mutualCount > 1 ? 's' : ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Friends list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FriendTile(
                    friend: friend,
                    currentUserUid: currentUserUid,
                    social: social,
                    auth: auth,
                    isMutualFriend: mutualFriendUids.contains(friend.uid),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows match status and history for a user's profile.
/// This section is PUBLIC - everyone can see anyone's match history.
class _MatchSection extends StatelessWidget {
  const _MatchSection({
    required this.currentUserUid,
    required this.currentUserGender,
    required this.profileUser,
    required this.social,
    this.auth,
  });

  final String currentUserUid;
  final Gender? currentUserGender;
  final AppUser profileUser;
  final FirestoreSocialGraphController social;
  final FirebaseAuthController? auth;

  /// Check if two users are opposite gender (male<->female only)
  bool get _isOppositeGender {
    if (currentUserGender == Gender.male) return profileUser.gender == Gender.female;
    if (currentUserGender == Gender.female) return profileUser.gender == Gender.male;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwnProfile = currentUserUid == profileUser.uid;

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
            Row(
              children: [
                Icon(Icons.favorite, size: 20, color: Colors.pink.shade400),
                const SizedBox(width: 8),
                Text(
                  'Relationship',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Current match status
            StreamBuilder<Match?>(
              stream: social.currentMatchStream(uid: profileUser.uid),
              builder: (context, matchSnap) {
                final currentMatch = matchSnap.data;
                final isMatched = currentMatch != null && currentMatch.isActive;

                if (isMatched) {
                  final partnerUid = currentMatch.otherUid(profileUser.uid);
                  return FutureBuilder<AppUser?>(
                    future: auth?.publicProfileByUid(partnerUid),
                    builder: (context, partnerSnap) {
                      final partner = partnerSnap.data;
                      final partnerName = partner?.username ?? 'Someone';

                      return Container(
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
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.pink.shade100,
                              backgroundImage: partner?.profileImageBytes != null
                                  ? MemoryImage(Uint8List.fromList(partner!.profileImageBytes!))
                                  : null,
                              child: partner?.profileImageBytes == null
                                  ? Icon(Icons.favorite, color: Colors.pink.shade400, size: 20)
                                  : null,
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
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.favorite, color: Colors.pink, size: 20),
                          ],
                        ),
                      );
                    },
                  );
                }

                // Not matched - show single status
                return Container(
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
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Single',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            // Match action button (only for other users' profiles AND opposite gender)
            if (!isOwnProfile && _isOppositeGender) ...[
              const SizedBox(height: 12),
              StreamBuilder<MatchStatus>(
                stream: social.matchStatusStream(myUid: currentUserUid, otherUid: profileUser.uid),
                builder: (context, statusSnap) {
                  final status = statusSnap.data;
                  if (status == null) {
                    return const SizedBox.shrink();
                  }

                  return FutureBuilder<String?>(
                    future: status.theirMatchPartnerUid != null && auth != null
                        ? auth!.publicProfileByUid(status.theirMatchPartnerUid!).then((u) => u?.username)
                        : Future.value(null),
                    builder: (context, partnerNameSnap) {
                      return MatchActionButton(
                        status: status,
                        otherUsername: profileUser.username,
                        theirPartnerUsername: partnerNameSnap.data,
                        onSendRequest: () => runAsyncAction(
                          context,
                          () => social.sendMatchRequest(fromUid: currentUserUid, toUid: profileUser.uid),
                          successMessage: 'Match request sent!',
                        ),
                        onAcceptRequest: () => runAsyncAction(
                          context,
                          () => social.acceptMatchRequest(toUid: currentUserUid, fromUid: profileUser.uid),
                          successMessage: 'You matched! 🎉',
                        ),
                        onBreakUp: () => runAsyncAction(
                          context,
                          () => social.breakMatch(uid: currentUserUid),
                          successMessage: 'Relationship ended',
                        ),
                      );
                    },
                  );
                },
              ),
            ],
            
            // View match history link
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: auth != null
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MatchHistoryPage(
                            profileUid: profileUser.uid,
                            profileUsername: profileUser.username,
                            currentUserUid: currentUserUid,
                            auth: auth!,
                            social: social,
                            isOwnProfile: isOwnProfile,
                          ),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.history, size: 18),
              label: Text(
                isOwnProfile ? 'View your match history' : 'View ${profileUser.username}\'s match history',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optimistic state for friend actions in _ActionCard
enum _OptimisticState {
  none,
  sending,    // Optimistically showing "Request sent"
  accepting,  // Optimistically showing "Friends"
}

class _ProfileActionButtons extends StatefulWidget {
  const _ProfileActionButtons({
    required this.status,
    required this.friendUsername,
    required this.canMessage,
    required this.onAdd,
    required this.onCancel,
    required this.onAccept,
    required this.onDecline,
    required this.onBlock,
    required this.onMessage,
  });

  final FriendStatus status;
  final String friendUsername;
  final bool canMessage;
  final VoidCallback onAdd;
  final VoidCallback onCancel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final Future<void> Function() onBlock;
  final VoidCallback onMessage;

  @override
  State<_ProfileActionButtons> createState() => _ProfileActionButtonsState();
}

class _ProfileActionButtonsState extends State<_ProfileActionButtons> {
  _OptimisticState _optimisticState = _OptimisticState.none;
  bool _isBlocking = false;
  bool _isOpeningChat = false;

  // Effective states (combining server state with optimistic state)
  bool get _effectiveAreFriends {
    if (_optimisticState == _OptimisticState.accepting) return true;
    return widget.status.areFriends;
  }

  bool get _effectiveHasOutgoing {
    if (_optimisticState == _OptimisticState.sending) return true;
    if (_optimisticState == _OptimisticState.accepting) return false;
    return widget.status.hasOutgoingRequest;
  }

  bool get _effectiveHasIncoming {
    if (_optimisticState == _OptimisticState.accepting) return false;
    return widget.status.hasIncomingRequest;
  }

  void _handleAdd() {
    setState(() => _optimisticState = _OptimisticState.sending);
    widget.onAdd();
  }

  void _handleAccept() {
    setState(() => _optimisticState = _OptimisticState.accepting);
    widget.onAccept();
  }

  Future<void> _handleMessage() async {
    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);
    try {
      widget.onMessage();
    } finally {
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
    }
  }

  Future<void> _handleBlock() async {
    if (_isBlocking) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User?'),
        content: Text('Are you sure you want to block ${widget.friendUsername}? They will not be able to chat with you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBlocking = true);

    try {
      await widget.onBlock();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to block user: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBlocking = false);
      }
    }
  }

  @override
  void didUpdateWidget(_ProfileActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear optimistic state when server state catches up
    if (widget.status.areFriends != oldWidget.status.areFriends ||
        widget.status.hasOutgoingRequest != oldWidget.status.hasOutgoingRequest ||
        widget.status.hasIncomingRequest != oldWidget.status.hasIncomingRequest) {
      _optimisticState = _OptimisticState.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action buttons row
          if (_effectiveAreFriends) ...[
            // Already friends - show Friends badge and Message button side by side
            Row(
              children: [
                // Friends status chip
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Friends',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.canMessage) ...[
                  const SizedBox(width: 12),
                  // Message button
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isOpeningChat ? null : _handleMessage,
                      icon: _isOpeningChat
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.chat_bubble_outline, size: 20),
                      label: const Text('Message'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Block button
            OutlinedButton.icon(
              onPressed: _isBlocking ? null : _handleBlock,
              icon: _isBlocking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.block, size: 18),
              label: const Text('Block user'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else if (_effectiveHasIncoming) ...[
            // Incoming request - show Accept and Message buttons side by side
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _handleAccept,
                    icon: const Icon(Icons.person_add_alt_1, size: 20),
                    label: const Text('Accept'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (widget.canMessage) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isOpeningChat ? null : _handleMessage,
                      icon: _isOpeningChat
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : const Icon(Icons.chat_bubble_outline, size: 20),
                      label: const Text('Message'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onDecline,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Decline request'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else if (_effectiveHasOutgoing) ...[
            // Outgoing request - show Request Sent and Message buttons side by side
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hourglass_top,
                          size: 18,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Request Sent',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.canMessage) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isOpeningChat ? null : _handleMessage,
                      icon: _isOpeningChat
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : const Icon(Icons.chat_bubble_outline, size: 20),
                      label: const Text('Message'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Cancel request'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else ...[
            // Not friends - show Add Friend and Message buttons side by side
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _handleAdd,
                    icon: const Icon(Icons.person_add, size: 20),
                    label: const Text('Add Friend'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (widget.canMessage) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isOpeningChat ? null : _handleMessage,
                      icon: _isOpeningChat
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : const Icon(Icons.chat_bubble_outline, size: 20),
                      label: const Text('Message'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Card shown when the current user has blocked the profile user.
/// Provides option to unblock.
class _BlockedUserCard extends StatefulWidget {
  const _BlockedUserCard({
    required this.friendUsername,
    required this.onUnblock,
  });

  final String friendUsername;
  final Future<void> Function() onUnblock;

  @override
  State<_BlockedUserCard> createState() => _BlockedUserCardState();
}

class _BlockedUserCardState extends State<_BlockedUserCard> {
  bool _isUnblocking = false;

  Future<void> _handleUnblock() async {
    if (_isUnblocking) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User?'),
        content: Text('Are you sure you want to unblock ${widget.friendUsername}? They will be able to send you friend requests and messages again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUnblocking = true);

    try {
      await widget.onUnblock();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unblock user: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUnblocking = false);
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Connection', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You have blocked this user',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isUnblocking ? null : _handleUnblock,
              icon: _isUnblocking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.lock_open),
              label: const Text('Unblock'),
            ),
          ],
        ),
      ),
    );
  }
}
