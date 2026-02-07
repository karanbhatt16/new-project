import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';
import '../widgets/async_error_view.dart';
import 'user_profile_page.dart';

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({
    super.key,
    required this.signedInUid,
    required this.auth,
    required this.social,
  });

  final String signedInUid;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Check if two users are opposite gender (male<->female only)
  bool _isOppositeGender(Gender? myGender, Gender? theirGender) {
    if (myGender == Gender.male) return theirGender == Gender.female;
    if (myGender == Gender.female) return theirGender == Gender.male;
    // For non-binary or prefer not to say, don't allow match requests
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
      ),
      body: StreamBuilder<AppUser?>(
        stream: widget.auth.profileStreamByUid(widget.signedInUid),
        builder: (context, currentUserSnap) {
          final currentUser = currentUserSnap.data;
          
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search friends…',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: StreamBuilder<Set<String>>(
                  stream: widget.social.friendsStream(uid: widget.signedInUid),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return AsyncErrorView(error: snap.error!);
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final uids = snap.data!.toList(growable: false);
                    if (uids.isEmpty) {
                      return Center(
                        child: Text(
                          'No friends yet.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      );
                    }

                    return FutureBuilder<List<AppUser>>(
                      future: widget.auth.publicProfilesByUids(uids),
                      builder: (context, usersSnap) {
                        if (usersSnap.hasError) {
                          return AsyncErrorView(error: usersSnap.error!);
                        }
                        if (!usersSnap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final q = _search.text.trim().toLowerCase();
                        var users = usersSnap.data!;
                        users.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));

                        if (q.isNotEmpty) {
                          users = users.where((u) => u.username.toLowerCase().contains(q)).toList(growable: false);
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          itemCount: users.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final u = users[index];
                            final canMatch = currentUser != null && 
                                _isOppositeGender(currentUser.gender, u.gender);
                            return _FriendTile(
                              friend: u,
                              currentUserUid: widget.signedInUid,
                              social: widget.social,
                              auth: widget.auth,
                              canMatch: canMatch,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A tile for a single friend, with match action button for opposite gender friends.
class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.currentUserUid,
    required this.social,
    required this.auth,
    required this.canMatch,
  });

  final AppUser friend;
  final String currentUserUid;
  final FirestoreSocialGraphController social;
  final FirebaseAuthController auth;
  final bool canMatch;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: friend.profileImageBytes != null
            ? MemoryImage(Uint8List.fromList(friend.profileImageBytes!))
            : null,
        child: friend.profileImageBytes == null ? const Icon(Icons.person) : null,
      ),
      title: Text(friend.username, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: null,
      // Only show match button for opposite gender friends
      trailing: canMatch
          ? _MatchActionIcon(
              friendUid: friend.uid,
              friendUsername: friend.username,
              currentUserUid: currentUserUid,
              social: social,
            )
          : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfilePage(
            currentUserUid: currentUserUid,
            user: friend,
            social: social,
            auth: auth,
          ),
        ),
      ),
    );
  }
}

/// Shows a heart icon button for sending match requests to friends.
/// Only shows for users who are not already matched.
class _MatchActionIcon extends StatelessWidget {
  const _MatchActionIcon({
    required this.friendUid,
    required this.friendUsername,
    required this.currentUserUid,
    required this.social,
  });

  final String friendUid;
  final String friendUsername;
  final String currentUserUid;
  final FirestoreSocialGraphController social;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MatchStatus>(
      stream: social.matchStatusStream(myUid: currentUserUid, otherUid: friendUid),
      builder: (context, snap) {
        // Show loading indicator while waiting
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pink.shade200),
              ),
            ),
          );
        }

        // Show error state or default icon if stream has error
        if (snap.hasError) {
          return Icon(Icons.favorite_border, color: Colors.pink.shade300);
        }

        final status = snap.data;
        if (status == null) {
          // Default: show the send match request button
          return IconButton(
            icon: Icon(Icons.favorite_border, color: Colors.pink.shade300),
            tooltip: 'Send match request to $friendUsername',
            onPressed: () => _sendMatchRequest(context),
          );
        }

        // Already matched with this person
        if (status.areMatched) {
          return Tooltip(
            message: 'You are matched with $friendUsername',
            child: Icon(Icons.favorite, color: Colors.pink.shade400),
          );
        }

        // I have an incoming request from them
        if (status.hasIncomingRequest) {
          return IconButton(
            icon: Icon(Icons.favorite, color: Colors.pink.shade300),
            tooltip: 'Accept match request from $friendUsername',
            onPressed: () => _acceptMatchRequest(context),
          );
        }

        // I sent a request to them (pending)
        if (status.hasOutgoingRequest) {
          return Tooltip(
            message: 'Match request pending',
            child: Icon(Icons.hourglass_top, color: Colors.grey.shade400),
          );
        }

        // I'm already matched with someone else
        if (status.iAmAlreadyMatched) {
          return Tooltip(
            message: 'You\'re already in a relationship',
            child: Icon(Icons.favorite_border, color: Colors.grey.shade300),
          );
        }

        // They're already matched with someone else
        if (status.theyAreAlreadyMatched) {
          return Tooltip(
            message: '$friendUsername is already in a relationship',
            child: Icon(Icons.heart_broken, color: Colors.grey.shade400),
          );
        }

        // Can send match request
        return IconButton(
          icon: Icon(Icons.favorite_border, color: Colors.pink.shade300),
          tooltip: 'Send match request to $friendUsername',
          onPressed: () => _sendMatchRequest(context),
        );
      },
    );
  }

  Future<void> _sendMatchRequest(BuildContext context) async {
    await runAsyncAction(
      context,
      () => social.sendMatchRequest(fromUid: currentUserUid, toUid: friendUid),
      successMessage: 'Match request sent to $friendUsername!',
    );
  }

  Future<void> _acceptMatchRequest(BuildContext context) async {
    await runAsyncAction(
      context,
      () => social.acceptMatchRequest(toUid: currentUserUid, fromUid: friendUid),
      successMessage: 'You matched with $friendUsername! 🎉',
    );
  }
}
