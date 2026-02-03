import 'package:flutter/material.dart';

import '../../auth/firebase_auth_controller.dart';
import '../../notifications/firestore_notifications_controller.dart';
import '../../notifications/notification_models.dart';
import '../widgets/async_error_view.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.signedInUid,
    required this.auth,
    required this.notifications,
  });

  final String signedInUid;
  final FirebaseAuthController auth;
  final FirestoreNotificationsController notifications;

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
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = items[index];

              return FutureBuilder(
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

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(actorName.isEmpty ? '?' : actorName.characters.first.toUpperCase()),
                    ),
                    title: Text(text),
                    subtitle: Text(_timeAgo(n.createdAt)),
                    trailing: n.read ? null : const Icon(Icons.circle, size: 10),
                    onTap: () async {
                      await notifications.markRead(uid: signedInUid, notificationId: n.id);
                      // TODO: navigate to relevant page (chat thread / friend requests / post)
                    },
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
