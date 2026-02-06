import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../call/voice_call_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../chat/firestore_chat_models.dart' show FirestoreChatThread, FirestoreMessage;
import '../../notifications/firestore_notifications_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';
import '_messages_widgets.dart';
import 'chat_thread_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({
    super.key,
    required this.signedInUid,
    required this.signedInEmail,
    required this.auth,
    required this.social,
    required this.chat,
    required this.notifications,
    required this.callController,
  });

  final String signedInUid;
  final String signedInEmail;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;
  final FirestoreChatController chat;
  final FirestoreNotificationsController notifications;
  final VoiceCallController callController;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openChatWith({required AppUser current, required AppUser other, bool isMatchChat = false}) async {
    final thread = await widget.chat.getOrCreateThread(
      myUid: current.uid,
      myEmail: current.email,
      otherUid: other.uid,
      otherEmail: other.email,
    );

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadPage(
          currentUser: current,
          otherUser: other,
          thread: thread,
          chat: widget.chat,
          social: widget.social,
          notifications: widget.notifications,
          callController: widget.callController,
          isMatchChat: isMatchChat,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: widget.auth.profileStreamByUid(widget.signedInUid),
      builder: (context, userSnap) {
        final currentUser = userSnap.data;
        if (currentUser == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<Set<String>>(
          stream: widget.social.friendsStream(uid: currentUser.uid),
          builder: (context, friendsSnap) {
            final friendUids = friendsSnap.data;
            if (friendUids == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<List<AppUser>>(
              stream: widget.auth.allUsersStream(),
              builder: (context, allSnap) {
                final allUsers = allSnap.data;
                if (allUsers == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final friends = allUsers.where((u) => friendUids.contains(u.uid)).toList(growable: false);
                friends.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));

                final theme = Theme.of(context);
                final query = _searchController.text.trim().toLowerCase();
                final matches = query.isEmpty
                    ? friends
                    : friends.where((u) => u.username.toLowerCase().contains(query)).toList(growable: false);

                final isDark = theme.brightness == Brightness.dark;

                return Container(
                  color: theme.colorScheme.surface,
                  child: Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: theme.textTheme.bodyLarge,
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: theme.colorScheme.primary.withValues(alpha: 0.7),
                              ),
                              hintText: 'Search friends...',
                              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          children: [
                            if (query.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.person_search_rounded,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Search Results',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (matches.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        size: 40,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No friends found',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                for (final u in matches)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildUserTile(u, currentUser, theme, isDark),
                                  ),
                              const SizedBox(height: 20),
                            ],

                          StreamBuilder<String?>(
                            stream: widget.auth.activeMatchWithUidStream(currentUser.uid),
                            builder: (context, matchSnap) {
                              final matchUid = matchSnap.data;
                              if (matchUid == null || matchUid.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              final matchUser = allUsers.where((u) => u.uid == matchUid).cast<AppUser?>().firstOrNull;
                              if (matchUser == null) {
                                return const SizedBox.shrink();
                              }

                              return StreamBuilder<String?>(
                                stream: widget.auth.activeCoupleThreadIdStream(currentUser.uid),
                                builder: (context, threadSnap) {
                                  final coupleThreadId = threadSnap.data;
                                  if (coupleThreadId == null || coupleThreadId.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Card(
                                      elevation: 0,
                                      child: ListTile(
                                        leading: const CircleAvatar(child: Icon(Icons.favorite)),
                                        title: Text(
                                          'Your Match · ${matchUser.username}',
                                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                        ),
                                        subtitle: Text(
                                          'Couple chat',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                        trailing: PopupMenuButton<String>(
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(value: 'end', child: Text('End match')),
                                          ],
                                          onSelected: (v) async {
                                            if (v != 'end') return;
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) {
                                                return AlertDialog(
                                                  title: const Text('End match?'),
                                                  content: const Text(
                                                    'This will end your match for both of you and delete the couple chat immediately.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.of(ctx).pop(false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () => Navigator.of(ctx).pop(true),
                                                      child: const Text('End match'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                            if (ok != true || !context.mounted) return;
                                            await runAsyncAction(
                                              context,
                                              () => widget.social.breakMatch(uid: currentUser.uid),
                                              successMessage: 'Match ended',
                                            );
                                          },
                                        ),
                                        onTap: () async {
                                          final thread = await widget.chat.getThreadById(coupleThreadId);
                                          if (thread == null || !context.mounted) return;
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ChatThreadPage(
                                                currentUser: currentUser,
                                                otherUser: matchUser,
                                                thread: thread,
                                                chat: widget.chat,
                                                social: widget.social,
                                                notifications: widget.notifications,
                                                callController: widget.callController,
                                                isMatchChat: true,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                          Text('Conversations',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),

                          StreamBuilder<List<FirestoreChatThread>>(
                            stream: widget.chat.threadsStream(myUid: currentUser.uid),
                            builder: (context, threadSnap) {
                              if (threadSnap.hasError) {
                                return Text(
                                  'Failed to load chats: ${threadSnap.error}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                                );
                              }

                              final threads = threadSnap.data;
                              if (threads == null) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }

                              if (threads.isEmpty) {
                                return Text(
                                  'No conversations yet. Search a friend above to start chatting.',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                );
                              }

                              return Column(
                                children: [
                                  for (final t in threads)
                                    Builder(
                                      builder: (context) {
                                        final otherUid = t.otherUid(currentUser.uid);
                                        final other = allUsers.where((u) => u.uid == otherUid).cast<AppUser?>().firstOrNull;

                                        if (other == null) {
                                          return const SizedBox.shrink();
                                        }

                                        return StreamBuilder<FirestoreMessage?>(
                                          stream: widget.chat.lastMessageStream(threadId: t.id),
                                          builder: (context, msgSnap) {
                                            final lastMsg = msgSnap.data;
                                            final lastMessageText = lastMsg != null 
                                                ? widget.chat.displayText(lastMsg) 
                                                : null;

                                            return StreamBuilder<int>(
                                              stream: widget.chat.unreadCountStream(
                                                threadId: t.id, 
                                                myUid: currentUser.uid,
                                              ),
                                              builder: (context, unreadSnap) {
                                                final unreadCount = unreadSnap.data ?? 0;

                                                return ConversationTile(
                                                  otherUser: other,
                                                  lastMessageText: lastMessageText,
                                                  unread: unreadCount,
                                                  onTap: () => _openChatWith(current: currentUser, other: other),
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildUserTile(AppUser user, AppUser currentUser, ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: UserAvatar(user: user, radius: 24),
        ),
        title: Text(
          user.username,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          user.email,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        onTap: () => _openChatWith(current: currentUser, other: user),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
