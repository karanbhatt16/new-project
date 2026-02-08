import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/skeleton_widgets.dart';
import 'user_profile_page.dart';

/// Friend requests page with optimistic UI updates.
/// Requests are hidden immediately when accepted/declined/cancelled,
/// before the server confirms the action.
class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({
    super.key,
    required this.currentUser,
    required this.auth,
    required this.social,
  });

  final AppUser currentUser;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  // Track requests that are being processed (for optimistic hide)
  final Set<String> _processingIncoming = {};
  final Set<String> _processingOutgoing = {};
  // Track requests that have been optimistically accepted (show success state briefly)
  final Set<String> _acceptedIncoming = {};

  Future<void> _handleAccept(String fromUid) async {
    setState(() {
      _acceptedIncoming.add(fromUid);
    });

    // Brief delay to show success state, then hide
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted) {
      setState(() {
        _processingIncoming.add(fromUid);
      });
    }

    // Fire and forget
    widget.social.acceptIncoming(toUid: widget.currentUser.uid, fromUid: fromUid).catchError((e) {
      if (mounted) {
        setState(() {
          _processingIncoming.remove(fromUid);
          _acceptedIncoming.remove(fromUid);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e')),
        );
      }
    });
  }

  Future<void> _handleDecline(String fromUid) async {
    setState(() {
      _processingIncoming.add(fromUid);
    });

    widget.social.declineIncoming(toUid: widget.currentUser.uid, fromUid: fromUid).catchError((e) {
      if (mounted) {
        setState(() {
          _processingIncoming.remove(fromUid);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline: $e')),
        );
      }
    });
  }

  Future<void> _handleCancel(String toUid) async {
    setState(() {
      _processingOutgoing.add(toUid);
    });

    widget.social.cancelOutgoing(fromUid: widget.currentUser.uid, toUid: toUid).catchError((e) {
      if (mounted) {
        setState(() {
          _processingOutgoing.remove(toUid);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e')),
        );
      }
    });
  }

  void _openUserProfile(AppUser user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          currentUserUid: widget.currentUser.uid,
          user: user,
          social: widget.social,
          auth: widget.auth,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Friend requests')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<int>(
            future: widget.social.friendsCount(uid: widget.currentUser.uid),
            builder: (context, snap) {
              final count = snap.data;
              return Text(
                count == null ? 'Friends: …' : 'Friends: $count',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              );
            },
          ),
          const SizedBox(height: 16),

          Text('Incoming', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          StreamBuilder<List<FriendRequest>>(
            stream: widget.social.incomingRequestsStream(uid: widget.currentUser.uid),
            builder: (context, snap) {
              final requests = snap.data;
              if (requests == null) {
                // Skeleton loading for requests
                return Column(
                  children: List.generate(2, (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: UserCardSkeleton(),
                  )),
                );
              }
              
              // Filter out requests that are being processed
              final visibleRequests = requests.where((r) => !_processingIncoming.contains(r.fromUid)).toList();
              
              if (visibleRequests.isEmpty) {
                return Text(
                  'No incoming requests.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              }

              return Column(
                children: [
                  for (final r in visibleRequests)
                    FutureBuilder<AppUser?>(
                      future: widget.auth.publicProfileByUid(r.fromUid),
                      builder: (context, uSnap) {
                        final u = uSnap.data;
                        final isAccepted = _acceptedIncoming.contains(r.fromUid);
                        
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Card(
                            elevation: 0,
                            color: isAccepted ? Colors.green.withValues(alpha: 0.1) : null,
                            child: ListTile(
                              leading: GestureDetector(
                                onTap: u != null ? () => _openUserProfile(u) : null,
                                child: const CircleAvatar(child: Icon(Icons.person)),
                              ),
                              title: GestureDetector(
                                onTap: u != null ? () => _openUserProfile(u) : null,
                                child: Text(u?.username ?? r.fromUid),
                              ),
                              trailing: isAccepted
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('Accepted!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                                      ],
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton(
                                          onPressed: () => _handleDecline(r.fromUid),
                                          child: const Text('Decline'),
                                        ),
                                        FilledButton(
                                          onPressed: () => _handleAccept(r.fromUid),
                                          child: const Text('Accept'),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),
          Text('Outgoing', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          StreamBuilder<List<FriendRequest>>(
            stream: widget.social.outgoingRequestsStream(uid: widget.currentUser.uid),
            builder: (context, snap) {
              final requests = snap.data;
              if (requests == null) {
                // Skeleton loading for outgoing requests
                return Column(
                  children: List.generate(2, (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: UserCardSkeleton(),
                  )),
                );
              }
              
              // Filter out requests that are being processed
              final visibleRequests = requests.where((r) => !_processingOutgoing.contains(r.toUid)).toList();
              
              if (visibleRequests.isEmpty) {
                return Text(
                  'No outgoing requests.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              }

              return Column(
                children: [
                  for (final r in visibleRequests)
                    FutureBuilder<AppUser?>(
                      future: widget.auth.publicProfileByUid(r.toUid),
                      builder: (context, uSnap) {
                        final u = uSnap.data;
                        return Card(
                          elevation: 0,
                          child: ListTile(
                            leading: GestureDetector(
                              onTap: u != null ? () => _openUserProfile(u) : null,
                              child: const CircleAvatar(child: Icon(Icons.person)),
                            ),
                            title: GestureDetector(
                              onTap: u != null ? () => _openUserProfile(u) : null,
                              child: Text(u?.username ?? r.toUid),
                            ),
                            trailing: OutlinedButton(
                              onPressed: () => _handleCancel(r.toUid),
                              child: const Text('Cancel'),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
