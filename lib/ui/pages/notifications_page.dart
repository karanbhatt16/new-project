import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../notifications/firestore_notifications_controller.dart';
import '../../notifications/notification_models.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';
import '../widgets/async_error_view.dart';
import '../widgets/skeleton_widgets.dart';
import 'user_profile_page.dart';

class NotificationsPage extends StatefulWidget {
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
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Automatically mark all notifications as read when page opens
    widget.notifications.markAllRead(uid: widget.signedInUid);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: widget.notifications.notificationsStream(uid: widget.signedInUid),
        builder: (context, snap) {
          if (snap.hasError) {
            return AsyncErrorView(error: snap.error!);
          }
          if (!snap.hasData) {
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: 6,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: NotificationSkeleton(),
              ),
            );
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
            cacheExtent: 500, // Cache more items for smoother scrolling
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final n = items[index];

              return FutureBuilder<AppUser?>(
                future: widget.auth.publicProfileByUid(n.fromUid),
                builder: (context, uSnap) {
                  final u = uSnap.data;
                  final actorName = u?.username ?? 'Someone';
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
                          title: _buildNotificationText(
                            context: context,
                            theme: theme,
                            actorName: actorName,
                            notificationType: n.type,
                            isRead: n.read,
                            user: u,
                            onUsernameTap: u != null
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => UserProfilePage(
                                          currentUserUid: widget.signedInUid,
                                          user: u,
                                          social: widget.social,
                                          auth: widget.auth,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
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
                            await widget.notifications.markRead(uid: widget.signedInUid, notificationId: n.id);
                          },
                        ),
                        // Show action buttons for friend requests
                        if (isFriendRequest && u != null)
                          StreamBuilder<FriendStatus>(
                            stream: widget.social.friendStatusStream(myUid: widget.signedInUid, otherUid: n.fromUid),
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
                                                currentUserUid: widget.signedInUid,
                                                user: u,
                                                social: widget.social,
                                                auth: widget.auth,
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
                                            await widget.social.acceptIncoming(
                                              toUid: widget.signedInUid,
                                              fromUid: n.fromUid,
                                            );
                                            await widget.notifications.markRead(
                                              uid: widget.signedInUid,
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

/// Builds the notification text with a tappable username that opens the user's profile.
Widget _buildNotificationText({
  required BuildContext context,
  required ThemeData theme,
  required String actorName,
  required NotificationType notificationType,
  required bool isRead,
  required AppUser? user,
  required VoidCallback? onUsernameTap,
}) {
  // Get the text parts before and after the username
  final (String prefix, String suffix) = switch (notificationType) {
    NotificationType.friendRequestSent => ('', ' sent you a friend request'),
    NotificationType.friendRequestAccepted => ('', ' accepted your friend request'),
    NotificationType.friendRequestDeclined => ('', ' declined your friend request'),
    NotificationType.friendRequestCancelled => ('', ' cancelled a friend request'),
    NotificationType.message => ('New message from ', ''),
    NotificationType.postLike => ('', ' liked your post'),
    NotificationType.postComment => ('', ' commented on your post'),
    NotificationType.storyLike => ('', ' liked your story'),
  };

  final baseStyle = theme.textTheme.bodyMedium?.copyWith(
    fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
  );

  final usernameStyle = baseStyle?.copyWith(
    color: theme.colorScheme.primary,
    fontWeight: FontWeight.w700,
  );

  return Text.rich(
    TextSpan(
      style: baseStyle,
      children: [
        if (prefix.isNotEmpty) TextSpan(text: prefix),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: onUsernameTap,
            child: Text(
              actorName,
              style: usernameStyle?.copyWith(
                decoration: onUsernameTap != null ? TextDecoration.underline : null,
                decorationColor: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        if (suffix.isNotEmpty) TextSpan(text: suffix),
      ],
    ),
  );
}
