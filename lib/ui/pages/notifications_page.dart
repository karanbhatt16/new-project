import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../notifications/firestore_notifications_controller.dart';
import '../../notifications/notification_models.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';
import '../widgets/async_error_view.dart';
import 'user_profile_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.signedInUid,
    required this.auth,
    required this.notifications,
    required this.social,
  });

  final String signedInUid;
  final FirebaseAuthController auth;
  final FirestoreNotificationsController notifications;
  final FirestoreSocialGraphController social;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            onPressed: () => notifications.markAllRead(uid: signedInUid),
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: notifications.notificationsStream(uid: signedInUid),
        builder: (context, snap) {
          if (snap.hasError) {
            return AsyncErrorView(error: snap.error!);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No activity yet.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final n = items[index];

              return FutureBuilder<AppUser?>(
                future: auth.publicProfileByUid(n.fromUid),
                builder: (context, uSnap) {
                  final u = uSnap.data;
                  final actorName = u?.username ?? 'Someone';

                  final text = switch (n.type) {
                    NotificationType.friendRequestSent => '$actorName sent you a friend request',
                    NotificationType.friendRequestAccepted => '$actorName accepted your friend request',
                    NotificationType.friendRequestDeclined => '$actorName declined your friend request',
                    NotificationType.friendRequestCancelled => '$actorName cancelled a friend request',
                    NotificationType.message => 'New message from $actorName',
                    NotificationType.postLike => '$actorName liked your post',
                    NotificationType.storyLike => '$actorName liked your story',
                  };

                  final isFriendRequest = n.type == NotificationType.friendRequestSent;

                  return Container(
                    decoration: BoxDecoration(
                      color: n.read
                          ? theme.colorScheme.surface
                          : theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: u?.profileImageBytes != null
                                ? MemoryImage(Uint8List.fromList(u!.profileImageBytes!))
                                : null,
                            child: u?.profileImageBytes == null
                                ? Text(
                                    actorName.isEmpty ? '?' : actorName.characters.first.toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  )
                                : null,
                          ),
                          title: Text(
                            text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: n.read ? FontWeight.w400 : FontWeight.w600,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _timeAgo(n.createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          trailing: !n.read
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                          onTap: () async {
                            await notifications.markRead(uid: signedInUid, notificationId: n.id);
                          },
                        ),
                        // Show action buttons for friend requests
                        if (isFriendRequest && u != null)
                          StreamBuilder<FriendStatus>(
                            stream: social.friendStatusStream(myUid: signedInUid, otherUid: n.fromUid),
                            builder: (context, statusSnap) {
                              final status = statusSnap.data;
                              // Only show buttons if there's still an incoming request
                              if (status == null || !status.hasIncomingRequest) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Row(
                                  children: [
                                    // View Profile button
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => UserProfilePage(
                                                currentUserUid: signedInUid,
                                                user: u,
                                                social: social,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.person_outline, size: 18),
                                        label: const Text('View Profile'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Accept button
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () => runAsyncAction(
                                          context,
                                          () async {
                                            await social.acceptIncoming(
                                              toUid: signedInUid,
                                              fromUid: n.fromUid,
                                            );
                                            await notifications.markRead(
                                              uid: signedInUid,
                                              notificationId: n.id,
                                            );
                                          },
                                        ),
                                        icon: const Icon(Icons.check_rounded, size: 18),
                                        label: const Text('Accept'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

String _timeAgo(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}
