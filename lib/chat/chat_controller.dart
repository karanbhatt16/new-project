import 'dart:math';

import 'package:flutter/foundation.dart';

import 'chat_models.dart';

/// Simple in-memory chat controller.
///
/// - One thread per unordered pair of users.
/// - Stores messages and unread counts.
class ChatController extends ChangeNotifier {
  final Map<String, ChatThread> _threadsById = <String, ChatThread>{};
  final Map<String, List<ChatMessage>> _messagesByThreadId = <String, List<ChatMessage>>{};

  /// Unread counts keyed by "threadId:userId".
  final Map<String, int> _unreadByThreadAndUser = <String, int>{};

  String _pairKey(String a, String b) {
    final aa = a.toLowerCase();
    final bb = b.toLowerCase();
    return (aa.compareTo(bb) <= 0) ? '$aa|$bb' : '$bb|$aa';
  }

  ChatThread getOrCreateThread(String userA, String userB) {
    final id = _pairKey(userA, userB);
    return _threadsById.putIfAbsent(
      id,
      () => ChatThread(id: id, userA: userA, userB: userB),
    );
  }

  List<ChatThread> threadsForUser(String userId) {
    final out = _threadsById.values
        .where((t) => t.userA == userId || t.userB == userId)
        .toList(growable: false);

    out.sort((a, b) {
      final aLast = lastMessageForThread(a.id);
      final bLast = lastMessageForThread(b.id);
      final aTime = aLast?.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = bLast?.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return out;
  }

  List<ChatMessage> messagesForThread(String threadId) =>
      List<ChatMessage>.unmodifiable(_messagesByThreadId[threadId] ?? const <ChatMessage>[]);

  ChatMessage? lastMessageForThread(String threadId) {
    final list = _messagesByThreadId[threadId];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  int unreadCount({required String threadId, required String userId}) =>
      _unreadByThreadAndUser['$threadId:$userId'] ?? 0;

  void markThreadRead({required String threadId, required String userId}) {
    final key = '$threadId:$userId';
    if ((_unreadByThreadAndUser[key] ?? 0) != 0) {
      _unreadByThreadAndUser[key] = 0;
      notifyListeners();
    }
  }

  void sendMessage({
    required String fromUserId,
    required String toUserId,
    required String text,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final thread = getOrCreateThread(fromUserId, toUserId);
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}_${Random().nextInt(1 << 32)}';

    final msg = ChatMessage(
      id: id,
      threadId: thread.id,
      fromUserId: fromUserId,
      toUserId: toUserId,
      text: trimmed,
      sentAt: now,
    );

    final list = _messagesByThreadId.putIfAbsent(thread.id, () => <ChatMessage>[]);
    list.add(msg);

    // Increment unread for recipient.
    final key = '${thread.id}:$toUserId';
    _unreadByThreadAndUser[key] = (_unreadByThreadAndUser[key] ?? 0) + 1;

    notifyListeners();
  }
}
