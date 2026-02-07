import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';
import 'match_action_button.dart';
import 'match_history_page.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({
    super.key,
    required this.currentUserUid,
    required this.user,
    required this.social,
    this.auth,
  });

  final String currentUserUid;
  final AppUser user;
  final FirestoreSocialGraphController social;
  final FirebaseAuthController? auth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(user.username)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundImage: user.profileImageBytes == null
                    ? null
                    : MemoryImage(Uint8List.fromList(user.profileImageBytes!)),
                child: user.profileImageBytes == null ? const Icon(Icons.person, size: 36) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
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
                  Text('About', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(user.bio.isEmpty ? 'No bio yet.' : user.bio),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(user.gender.label)),
                      for (final i in user.interests) Chip(label: Text(i)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<FriendStatus>(
            stream: social.friendStatusStream(myUid: currentUserUid, otherUid: user.uid),
            builder: (context, snap) {
              final s = snap.data;
              if (s == null) {
                return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
              }

              return Column(
                children: [
                  _ActionCard(
                    status: s,
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
                  ),
                  // Show friends list if we're friends with this user
                  if (s.areFriends && auth != null) ...[
                    const SizedBox(height: 12),
                    _FriendsSection(
                      currentUserUid: currentUserUid,
                      profileUserUid: user.uid,
                      profileUsername: user.username,
                      social: social,
                      auth: auth!,
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // Match Section - visible to everyone
          _MatchSection(
            currentUserUid: currentUserUid,
            profileUser: user,
            social: social,
            auth: auth,
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
    required this.profileUser,
    required this.social,
    this.auth,
  });

  final String currentUserUid;
  final AppUser profileUser;
  final FirestoreSocialGraphController social;
  final FirebaseAuthController? auth;

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
            
            // Match action button (only for other users' profiles)
            if (!isOwnProfile) ...[
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.status,
    required this.onAdd,
    required this.onCancel,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendStatus status;
  final VoidCallback onAdd;
  final VoidCallback onCancel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

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
            if (status.areFriends) ...[
              FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.check),
                label: const Text('Friends'),
              ),
            ] else if (status.hasIncomingRequest) ...[
              FilledButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Accept request'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onDecline,
                icon: const Icon(Icons.close),
                label: const Text('Decline'),
              ),
            ] else if (status.hasOutgoingRequest) ...[
              FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.hourglass_top),
                label: const Text('Requested'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.undo),
                label: const Text('Cancel request'),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add),
                label: const Text('Add friend'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
