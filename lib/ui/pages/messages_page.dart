import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/local_auth_controller.dart';
import '../../chat/chat_controller.dart';
import '../../social/social_graph_controller.dart';
import 'chat_thread_page.dart';
import '_messages_widgets.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({
    super.key,
    required this.signedInEmail,
    required this.auth,
    required this.social,
    required this.chat,
  });

  final String signedInEmail;
  final LocalAuthController auth;
  final SocialGraphController social;
  final ChatController chat;

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

  AppUser get _currentUser => widget.auth.userByEmail(widget.signedInEmail)!;

  List<AppUser> get _friends {
    final me = widget.signedInEmail;
    final out = widget.auth.allUsers
        .where((u) => u.email != me && widget.social.areFriends(me, u.email))
        .toList(growable: false);

    out.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    return out;
  }

  void _openChatWith(AppUser other) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadPage(
          currentUser: _currentUser,
          otherUser: other,
          chat: widget.chat,
          social: widget.social,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.chat, widget.social]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final friends = _friends;

        final query = _searchController.text.trim().toLowerCase();
        final matches = query.isEmpty
            ? friends
            : friends.where((u) => u.username.toLowerCase().contains(query)).toList(growable: false);

        final threads = widget.chat.threadsForUser(widget.signedInEmail);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search friends by username to chat…',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            if (query.isNotEmpty) ...[
              Text('Start chat', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (matches.isEmpty)
                Text(
                  'No friends match “${_searchController.text.trim()}”.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else
                for (final u in matches)
                  UserStartTile(
                    user: u,
                    onTap: () => _openChatWith(u),
                  ),
              const SizedBox(height: 16),
            ],

            Text('Conversations', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (threads.isEmpty)
              Text(
                'No conversations yet. Search a friend above to start chatting.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final t in threads)
                ConversationTile(
                  otherUser: widget.auth.userByEmail(t.otherUserId(widget.signedInEmail))!,
                  lastMessage: widget.chat.lastMessageForThread(t.id),
                  unread: widget.chat.unreadCount(threadId: t.id, userId: widget.signedInEmail),
                  onTap: () => _openChatWith(
                    widget.auth.userByEmail(t.otherUserId(widget.signedInEmail))!,
                  ),
                ),
          ],
        );
      },
    );
  }
}

