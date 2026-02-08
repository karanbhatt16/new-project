import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../call/voice_call_controller.dart';
import '../../chat/e2ee_chat_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../notifications/firestore_notifications_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_error_view.dart';
import 'chat_thread_page.dart';
import 'user_profile_page.dart';

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({
    super.key,
    required this.signedInUid,
    required this.auth,
    required this.social,
    this.chat,
    this.e2eeChat,
    this.notifications,
    this.callController,
  });

  final String signedInUid;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;
  final FirestoreChatController? chat;
  final E2eeChatController? e2eeChat;
  final FirestoreNotificationsController? notifications;
  final VoiceCallController? callController;

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

  /// Opens a chat with the given friend.
  /// Returns true if chat was opened, false if required controllers are missing.
  Future<void> _openChat(
    BuildContext context,
    String currentUserUid,
    AppUser friend,
    FirebaseAuthController auth,
    FirestoreChatController chat,
    E2eeChatController e2eeChat,
    FirestoreSocialGraphController social,
    FirestoreNotificationsController notifications,
    VoiceCallController callController,
  ) async {
    // Get current user profile
    final currentUser = await auth.publicProfileByUid(currentUserUid);
    if (currentUser == null || !context.mounted) return;

    // Get or create thread
    final thread = await chat.getOrCreateThread(
      myUid: currentUserUid,
      myEmail: currentUser.email,
      otherUid: friend.uid,
      otherEmail: friend.email,
    );

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadPage(
          currentUser: currentUser,
          otherUser: friend,
          thread: thread,
          chat: chat,
          e2eeChat: e2eeChat,
          social: social,
          notifications: notifications,
          callController: callController,
          isMatchChat: false,
        ),
      ),
    );
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
                              onMessage: (widget.chat != null && 
                                          widget.e2eeChat != null && 
                                          widget.notifications != null && 
                                          widget.callController != null)
                                  ? () => _openChat(
                                        context,
                                        widget.signedInUid,
                                        u,
                                        widget.auth,
                                        widget.chat!,
                                        widget.e2eeChat!,
                                        widget.social,
                                        widget.notifications!,
                                        widget.callController!,
                                      )
                                  : null,
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
    this.onMessage,
  });

  final AppUser friend;
  final String currentUserUid;
  final FirestoreSocialGraphController social;
  final FirebaseAuthController auth;
  final bool canMatch;
  final VoidCallback? onMessage;

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
            onMessage: onMessage,
          ),
        ),
      ),
    );
  }
}

/// Optimistic state for match actions
enum _OptimisticMatchState {
  none,
  sending,    // Optimistically showing "Request pending"
  accepting,  // Optimistically showing "Matched"
}

/// Shows a heart icon button for sending match requests to friends.
/// Only shows for users who are not already matched.
/// Now with optimistic UI - changes appear instantly before server confirms.
class _MatchActionIcon extends StatefulWidget {
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
  State<_MatchActionIcon> createState() => _MatchActionIconState();
}

class _MatchActionIconState extends State<_MatchActionIcon> {
  _OptimisticMatchState _optimisticState = _OptimisticMatchState.none;

  void _handleSendRequest() {
    setState(() => _optimisticState = _OptimisticMatchState.sending);
    
    widget.social.sendMatchRequest(
      fromUid: widget.currentUserUid, 
      toUid: widget.friendUid,
    ).catchError((e) {
      if (mounted) {
        setState(() => _optimisticState = _OptimisticMatchState.none);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    });
  }

  void _handleAcceptRequest() {
    setState(() => _optimisticState = _OptimisticMatchState.accepting);
    
    widget.social.acceptMatchRequest(
      toUid: widget.currentUserUid, 
      fromUid: widget.friendUid,
    ).catchError((e) {
      if (mounted) {
        setState(() => _optimisticState = _OptimisticMatchState.none);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MatchStatus>(
      stream: widget.social.matchStatusStream(myUid: widget.currentUserUid, otherUid: widget.friendUid),
      builder: (context, snap) {
        // Clear optimistic state when server catches up
        if (snap.hasData) {
          final status = snap.data!;
          if (_optimisticState == _OptimisticMatchState.sending && status.hasOutgoingRequest) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _optimisticState = _OptimisticMatchState.none);
            });
          }
          if (_optimisticState == _OptimisticMatchState.accepting && status.areMatched) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _optimisticState = _OptimisticMatchState.none);
            });
          }
        }

        // Show loading indicator while waiting for initial data
        if (snap.connectionState == ConnectionState.waiting && _optimisticState == _OptimisticMatchState.none) {
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
        if (snap.hasError && _optimisticState == _OptimisticMatchState.none) {
          return Icon(Icons.favorite_border, color: Colors.pink.shade300);
        }

        final status = snap.data;
        
        // Apply optimistic state
        final effectiveAreMatched = _optimisticState == _OptimisticMatchState.accepting || (status?.areMatched ?? false);
        final effectiveHasOutgoing = _optimisticState == _OptimisticMatchState.sending || (status?.hasOutgoingRequest ?? false);
        final effectiveHasIncoming = _optimisticState == _OptimisticMatchState.none && (status?.hasIncomingRequest ?? false);

        // Already matched with this person
        if (effectiveAreMatched) {
          return Tooltip(
            message: 'You are matched with ${widget.friendUsername}',
            child: Icon(Icons.favorite, color: Colors.pink.shade400),
          );
        }

        // I sent a request to them (pending) - check this before incoming
        if (effectiveHasOutgoing) {
          return Tooltip(
            message: 'Match request pending',
            child: Icon(Icons.hourglass_top, color: Colors.grey.shade400),
          );
        }

        // I have an incoming request from them
        if (effectiveHasIncoming) {
          return IconButton(
            icon: Icon(Icons.favorite, color: Colors.pink.shade300),
            tooltip: 'Accept match request from ${widget.friendUsername}',
            onPressed: _handleAcceptRequest,
          );
        }

        // I'm already matched with someone else
        if (status?.iAmAlreadyMatched ?? false) {
          return Tooltip(
            message: 'You\'re already in a relationship',
            child: Icon(Icons.favorite_border, color: Colors.grey.shade300),
          );
        }

        // They're already matched with someone else
        if (status?.theyAreAlreadyMatched ?? false) {
          return Tooltip(
            message: '${widget.friendUsername} is already in a relationship',
            child: Icon(Icons.heart_broken, color: Colors.grey.shade400),
          );
        }

        // Can send match request
        return IconButton(
          icon: Icon(Icons.favorite_border, color: Colors.pink.shade300),
          tooltip: 'Send match request to ${widget.friendUsername}',
          onPressed: _handleSendRequest,
        );
      },
    );
  }
}
