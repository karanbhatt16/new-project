import 'package:flutter/foundation.dart';

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.fromUserId,
    required this.toUserId,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String threadId;
  final String fromUserId;
  final String toUserId;
  final String text;
  final DateTime sentAt;
}

@immutable
class ChatThread {
  const ChatThread({
    required this.id,
    required this.userA,
    required this.userB,
  });

  final String id;
  final String userA;
  final String userB;

  String otherUserId(String currentUserId) => userA == currentUserId ? userB : userA;
}
