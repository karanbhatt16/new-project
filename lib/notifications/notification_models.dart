import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum NotificationType {
  friendRequestSent,
  friendRequestAccepted,
  friendRequestDeclined,
  friendRequestCancelled,
  message,
  postLike,
  storyLike,
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.toUid,
    required this.fromUid,
    required this.type,
    required this.createdAt,
    required this.read,
    this.threadId,
    this.targetId,
  });

  final String id;
  final String toUid;
  final String fromUid;
  final NotificationType type;
  final DateTime createdAt;
  final bool read;

  // Optional payload.
  final String? threadId;
  final String? targetId;

  static NotificationType _typeFromString(String raw) {
    return NotificationType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => NotificationType.message,
    );
  }

  static AppNotification fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AppNotification(
      id: doc.id,
      toUid: d['toUid'] as String,
      fromUid: d['fromUid'] as String,
      type: _typeFromString(d['type'] as String),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      read: (d['read'] as bool?) ?? false,
      threadId: d['threadId'] as String?,
      targetId: d['targetId'] as String?,
    );
  }
}
