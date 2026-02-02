import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../chat/chat_controller.dart';
import '../../social/social_graph_controller.dart';

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.currentUser,
    required this.otherUser,
    required this.chat,
    required this.social,
  });

  final AppUser currentUser;
  final AppUser otherUser;
  final ChatController chat;
  final SocialGraphController social;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.chat,
      builder: (context, _) {
        final currentId = widget.currentUser.email;
        final otherId = widget.otherUser.email;

        final areFriends = widget.social.areFriends(currentId, otherId);
        final thread = widget.chat.getOrCreateThread(currentId, otherId);
        final messages = widget.chat.messagesForThread(thread.id);

        // Mark as read whenever we show the thread.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.chat.markThreadRead(threadId: thread.id, userId: currentId);
        });

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.otherUser.username),
          ),
          body: Column(
            children: [
              if (!areFriends)
                MaterialBanner(
                  content: const Text('You can only chat with friends. Send/accept a friend request first.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[messages.length - 1 - index];
                    final isMe = m.fromUserId == currentId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Card(
                          elevation: 0,
                          color: isMe
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Text(m.text),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: areFriends,
                          decoration: const InputDecoration(
                            hintText: 'Message…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: areFriends
                              ? (value) {
                                  widget.chat.sendMessage(
                                    fromUserId: currentId,
                                    toUserId: otherId,
                                    text: value,
                                  );
                                  _controller.clear();
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: areFriends
                            ? () {
                                widget.chat.sendMessage(
                                  fromUserId: currentId,
                                  toUserId: otherId,
                                  text: _controller.text,
                                );
                                _controller.clear();
                              }
                            : null,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
