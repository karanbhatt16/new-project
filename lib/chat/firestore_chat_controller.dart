import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../auth/firebase_auth_controller.dart';
import '../notifications/firestore_notifications_controller.dart';
import '../notifications/notification_models.dart';
import 'firestore_chat_models.dart';

/// Firestore-backed chat (plaintext messages).
///
/// Schema:
/// threads/{threadId}:
///   userAUid, userBUid, userAEmail, userBEmail, updatedAt
/// threads/{threadId}/messages/{messageId}:
///   fromUid, toUid, text, sentAt
///
/// Notes:
/// - Older encrypted messages are tolerated and shown as "[Encrypted message]".
class FirestoreChatController extends ChangeNotifier {
  FirestoreChatController({
    required this.auth,
    FirebaseFirestore? firestore,
    FirestoreNotificationsController? notifications,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _notifications = notifications ??
            FirestoreNotificationsController(firestore: firestore ?? FirebaseFirestore.instance);

  final FirebaseAuthController auth;
  final FirebaseFirestore _db;
  final FirestoreNotificationsController _notifications;

  String _threadIdForUids(String a, String b) {
    final aa = a.compareTo(b) <= 0 ? a : b;
    final bb = a.compareTo(b) <= 0 ? b : a;
    return '$aa|$bb';
  }

  Future<FirestoreChatThread> getOrCreateThread({
    required String myUid,
    required String myEmail,
    required String otherUid,
    required String otherEmail,
  }) async {
    final id = _threadIdForUids(myUid, otherUid);
    final doc = _db.collection('threads').doc(id);

    // Calculate the canonical order for userA and userB
    final userAUid = myUid.compareTo(otherUid) <= 0 ? myUid : otherUid;
    final userBUid = myUid.compareTo(otherUid) <= 0 ? otherUid : myUid;
    final userAEmail = myUid.compareTo(otherUid) <= 0 ? myEmail : otherEmail;
    final userBEmail = myUid.compareTo(otherUid) <= 0 ? otherEmail : myEmail;

    // Try to read existing thread - may fail with permission error if thread doesn't exist
    // because Firestore rules can't evaluate canAccessThread on a non-existent document
    try {
      final existingSnap = await doc.get();
      
      if (existingSnap.exists) {
        // Thread exists - just return it without updating timestamp
        // This prevents the conversation from jumping to top when just opened
        final data = existingSnap.data() as Map<String, dynamic>;
        return FirestoreChatThread(
          id: id,
          userAUid: data['userAUid'] as String,
          userBUid: data['userBUid'] as String,
          userAEmail: (data['userAEmail'] as String?) ?? '',
          userBEmail: (data['userBEmail'] as String?) ?? '',
          lastMessageAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        );
      }
    } catch (e) {
      // Permission error or thread doesn't exist - proceed to create
      // This is expected for new threads since rules require the document to exist
      debugPrint('getOrCreateThread: Read failed (expected for new threads): $e');
    }

    // Thread doesn't exist - create it with timestamp
    try {
      await doc.set({
        'type': 'direct',
        'userAUid': userAUid,
        'userBUid': userBUid,
        'userAEmail': userAEmail,
        'userBEmail': userBEmail,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('getOrCreateThread: Create failed: $e');
      // Thread might already exist (race condition) - try reading again
      try {
        final snap = await doc.get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          return FirestoreChatThread(
            id: id,
            userAUid: data['userAUid'] as String,
            userBUid: data['userBUid'] as String,
            userAEmail: (data['userAEmail'] as String?) ?? '',
            userBEmail: (data['userBEmail'] as String?) ?? '',
            lastMessageAt: (data['updatedAt'] as Timestamp?)?.toDate(),
          );
        }
      } catch (_) {
        // Ignore and rethrow original error
      }
      rethrow;
    }

    // Return immediately using the data we just wrote (avoid extra read)
    // This prevents permission issues when reading right after creation
    return FirestoreChatThread(
      id: id,
      userAUid: userAUid,
      userBUid: userBUid,
      userAEmail: userAEmail,
      userBEmail: userBEmail,
      lastMessageAt: DateTime.now(), // Use local time as approximation
    );
  }

  /// Create a dedicated couple thread for a match.
  ///
  /// Thread id is random so it doesn't collide with direct threads.
  Future<FirestoreChatThread> createCoupleThread({
    required String uidA,
    required String emailA,
    required String uidB,
    required String emailB,
    String? matchId,
  }) async {
    final doc = _db.collection('threads').doc();

    final aUid = uidA.compareTo(uidB) <= 0 ? uidA : uidB;
    final bUid = uidA.compareTo(uidB) <= 0 ? uidB : uidA;
    final aEmail = uidA.compareTo(uidB) <= 0 ? emailA : emailB;
    final bEmail = uidA.compareTo(uidB) <= 0 ? emailB : emailA;

    await doc.set({
      'type': 'couple',
      'userAUid': aUid,
      'userBUid': bUid,
      'userAEmail': aEmail,
      'userBEmail': bEmail,
      if (matchId != null) 'matchId': matchId,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    final snap = await doc.get();
    final data = snap.data() as Map<String, dynamic>;

    return FirestoreChatThread(
      id: doc.id,
      userAUid: data['userAUid'] as String,
      userBUid: data['userBUid'] as String,
      userAEmail: data['userAEmail'] as String,
      userBEmail: data['userBEmail'] as String,
      lastMessageAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Future<FirestoreChatThread?> getThreadById(String threadId) async {
    final doc = await _db.collection('threads').doc(threadId).get();
    final data = doc.data();
    if (data == null) return null;

    return FirestoreChatThread(
      id: doc.id,
      userAUid: data['userAUid'] as String,
      userBUid: data['userBUid'] as String,
      userAEmail: (data['userAEmail'] as String?) ?? '',
      userBEmail: (data['userBEmail'] as String?) ?? '',
      lastMessageAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Stream of chat threads for a user.
  /// 
  /// Uses Firestore's offline persistence to show cached threads when offline.
  Stream<List<FirestoreChatThread>> threadsStream({required String myUid}) {
    // Use a single OR query so the stream emits immediately and we don't get
    // stuck waiting for two separate listeners.
    // IMPORTANT: Your Firestore rules restrict couple threads (type=='couple')
    // to only be readable while still matched. That makes a broad list query fail.
    // So we only list direct threads here. Couple chat is opened via its id.
    final q = _db.collection('threads').where(
          Filter.and(
            Filter.or(
              Filter('userAUid', isEqualTo: myUid),
              Filter('userBUid', isEqualTo: myUid),
            ),
            // Backward compatible: older threads may not have `type`.
            Filter.or(
              Filter('type', isEqualTo: 'direct'),
              Filter('type', isNull: true),
            ),
          ),
        );

    return q.snapshots(includeMetadataChanges: true).map((snap) {
      final threads = snap.docs.map((d) {
        final data = d.data();
        return FirestoreChatThread(
          id: d.id,
          userAUid: data['userAUid'] as String,
          userBUid: data['userBUid'] as String,
          userAEmail: (data['userAEmail'] as String?) ?? '',
          userBEmail: (data['userBEmail'] as String?) ?? '',
          lastMessageAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        );
      }).toList(growable: false);

      threads.sort((x, y) => (y.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(x.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      return threads;
    });
  }

  /// Stream of messages for a thread.
  /// 
  /// Uses Firestore's offline persistence to show cached messages when offline.
  /// The [includeMetadataChanges] option ensures we get updates from cache immediately.
  Stream<List<FirestoreMessage>> messagesStream({required String threadId}) {
    return _db
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.map((d) => FirestoreMessage.fromDoc(threadId: threadId, doc: d)).toList());
  }

  Future<String> sendMessagePlaintext({
    required String threadId,
    required String fromUid,
    required String fromEmail,
    required String toUid,
    required String toEmail,
    required String text,
    String? replyToMessageId,
    String? replyToFromUid,
    String? replyToText,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('text is empty');
    }

    // Use local timestamp as fallback for immediate display, server timestamp for consistency
    final now = DateTime.now();
    final msgDoc = _db.collection('threads').doc(threadId).collection('messages').doc();
    await msgDoc.set({
      'fromUid': fromUid,
      'toUid': toUid,
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
      'sentAtLocal': Timestamp.fromDate(now), // Local fallback for pending writes
      'replyToMessageId': replyToMessageId,
      'replyToFromUid': replyToFromUid,
      'replyToText': replyToText,
      'status': 'sent', // Message delivery status
    });

    await _db.collection('threads').doc(threadId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Best-effort notification (if rules block this, message should still exist).
    try {
      await _notifications.create(
        toUid: toUid,
        fromUid: fromUid,
        type: NotificationType.message,
        threadId: threadId,
      );
    } catch (e) {
      // ignore: avoid_print
      print('Failed to create message notification: $e');
    }

    return msgDoc.id;
  }

  /// Sends an end-to-end encrypted message.
  ///
  /// The message content is encrypted before being stored in Firestore.
  /// Only the sender and recipient can decrypt the message.
  Future<String> sendEncryptedMessage({
    required String threadId,
    required String fromUid,
    required String toUid,
    required String ciphertextB64,
    required String nonceB64,
    required String macB64,
    String? replyToMessageId,
    String? replyToFromUid,
    String? replyToTextEncrypted,
  }) async {
    final now = DateTime.now();
    final msgDoc = _db.collection('threads').doc(threadId).collection('messages').doc();
    await msgDoc.set({
      'fromUid': fromUid,
      'toUid': toUid,
      'ciphertextB64': ciphertextB64,
      'nonceB64': nonceB64,
      'macB64': macB64,
      'sentAt': FieldValue.serverTimestamp(),
      'sentAtLocal': Timestamp.fromDate(now),
      'replyToMessageId': replyToMessageId,
      'replyToFromUid': replyToFromUid,
      'replyToTextEncrypted': replyToTextEncrypted,
      'status': 'sent', // Message delivery status
    });

    await _db.collection('threads').doc(threadId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Best-effort notification
    try {
      await _notifications.create(
        toUid: toUid,
        fromUid: fromUid,
        type: NotificationType.message,
        threadId: threadId,
      );
    } catch (e) {
      print('Failed to create message notification: $e');
    }

    return msgDoc.id;
  }

  /// Sends an end-to-end encrypted voice message.
  ///
  /// The voice URL is encrypted before being stored in Firestore.
  Future<String> sendEncryptedVoiceMessage({
    required String threadId,
    required String fromUid,
    required String toUid,
    required String voiceUrlCiphertextB64,
    required String voiceUrlNonceB64,
    required String voiceUrlMacB64,
    required int durationSeconds,
    String? replyToMessageId,
    String? replyToFromUid,
    String? replyToTextEncrypted,
  }) async {
    final now = DateTime.now();
    final msgDoc = _db.collection('threads').doc(threadId).collection('messages').doc();

    await msgDoc.set({
      'fromUid': fromUid,
      'toUid': toUid,
      'messageType': 'voice',
      'voiceUrlCiphertextB64': voiceUrlCiphertextB64,
      'voiceUrlNonceB64': voiceUrlNonceB64,
      'voiceUrlMacB64': voiceUrlMacB64,
      'voiceDurationSeconds': durationSeconds,
      'sentAt': FieldValue.serverTimestamp(),
      'sentAtLocal': Timestamp.fromDate(now),
      'replyToMessageId': replyToMessageId,
      'replyToFromUid': replyToFromUid,
      'replyToTextEncrypted': replyToTextEncrypted,
      'status': 'sent', // Message delivery status
    });

    await _db.collection('threads').doc(threadId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Best-effort notification
    try {
      await _notifications.create(
        toUid: toUid,
        fromUid: fromUid,
        type: NotificationType.message,
        threadId: threadId,
      );
    } catch (e) {
      print('Failed to create voice message notification: $e');
    }

    return msgDoc.id;
  }

  /// Toggles a reaction on a message.
  /// 
  /// WhatsApp-style: Each user can only have ONE reaction per message.
  /// If the user already reacted with the same emoji, it removes the reaction.
  /// If the user reacted with a different emoji, it replaces the old reaction.
  Future<void> toggleReaction({
    required String threadId,
    required String messageId,
    required String emoji,
    required String uid,
  }) async {
    final msgRef = _db.collection('threads').doc(threadId).collection('messages').doc(messageId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(msgRef);
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      final reactions = Map<String, dynamic>.from(
        (data['reactions'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      );

      // First, remove the user from any existing reaction (WhatsApp allows only one reaction per user)
      for (final key in reactions.keys.toList()) {
        final users = (reactions[key] as List?)?.whereType<String>().toList() ?? <String>[];
        if (users.contains(uid)) {
          users.remove(uid);
          if (users.isEmpty) {
            reactions.remove(key);
          } else {
            reactions[key] = users;
          }
        }
      }

      // Now add the new reaction (unless user tapped the same emoji to remove it)
      final existingForEmoji = (reactions[emoji] as List?)?.whereType<String>().toList() ?? <String>[];
      
      // Check if user previously had this exact emoji (means they want to remove it)
      final hadSameEmoji = (data['reactions'] as Map<String, dynamic>?)
          ?.entries
          .any((e) => e.key == emoji && ((e.value as List?)?.contains(uid) ?? false)) ?? false;

      if (!hadSameEmoji) {
        // Add new reaction
        existingForEmoji.add(uid);
        reactions[emoji] = existingForEmoji;
      }

      tx.update(msgRef, {'reactions': reactions});
    });
  }

  String displayText(FirestoreMessage message, {String? forUid}) {
    // Check if message is deleted for this user
    if (forUid != null && message.isDeletedFor(forUid)) {
      return 'This message was deleted';
    }
    if (message.deletedForEveryone) {
      return 'This message was deleted';
    }
    if (message.isCallMessage) {
      return _getCallDisplayText(message);
    }
    if (message.isVoiceMessage) {
      return _getVoiceDisplayText(message);
    }
    if (message.text != null) return message.text!;
    if (message.ciphertextB64 != null) return '[Encrypted message]';
    return '[Unsupported message]';
  }

  String _getVoiceDisplayText(FirestoreMessage message) {
    final duration = message.voiceDurationSeconds ?? 0;
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '🎤 Voice message · $minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _getCallDisplayText(FirestoreMessage message) {
    final duration = message.formattedCallDuration;
    switch (message.callStatus) {
      case CallMessageStatus.completed:
        return 'Voice call · $duration';
      case CallMessageStatus.missed:
        return 'Missed voice call';
      case CallMessageStatus.declined:
        return 'Declined voice call';
      case CallMessageStatus.cancelled:
        return 'Cancelled voice call';
      default:
        return 'Voice call';
    }
  }

  /// Deletes a message for the current user only.
  /// 
  /// The message will still be visible to the other user.
  Future<void> deleteMessageForMe({
    required String threadId,
    required String messageId,
    required String uid,
  }) async {
    final msgRef = _db.collection('threads').doc(threadId).collection('messages').doc(messageId);
    await msgRef.update({
      'deletedForUsers': FieldValue.arrayUnion([uid]),
    });
  }

  /// Deletes a message for everyone in the conversation.
  /// 
  /// Only the sender can delete a message for everyone.
  /// The message content is cleared and marked as deleted.
  Future<void> deleteMessageForEveryone({
    required String threadId,
    required String messageId,
    required String senderUid,
  }) async {
    final msgRef = _db.collection('threads').doc(threadId).collection('messages').doc(messageId);
    
    // Verify the user is the sender before allowing delete for everyone
    final doc = await msgRef.get();
    if (!doc.exists) return;
    
    final data = doc.data();
    if (data == null || data['fromUid'] != senderUid) {
      throw Exception('Only the sender can delete a message for everyone');
    }

    await msgRef.update({
      'deletedForEveryone': true,
      'text': null, // Clear the message content
      'ciphertextB64': null,
      'nonceB64': null,
      'macB64': null,
    });
  }

  /// Deletes multiple messages for the current user only.
  Future<void> deleteMessagesForMe({
    required String threadId,
    required List<String> messageIds,
    required String uid,
  }) async {
    final batch = _db.batch();
    for (final messageId in messageIds) {
      final msgRef = _db.collection('threads').doc(threadId).collection('messages').doc(messageId);
      batch.update(msgRef, {
        'deletedForUsers': FieldValue.arrayUnion([uid]),
      });
    }
    await batch.commit();
  }

  /// Deletes multiple messages for everyone (only messages sent by the user).
  /// 
  /// Returns the count of messages that were deleted for everyone.
  /// Messages not sent by the user will be skipped.
  Future<int> deleteMessagesForEveryone({
    required String threadId,
    required List<String> messageIds,
    required String senderUid,
  }) async {
    int deletedCount = 0;
    final batch = _db.batch();
    
    for (final messageId in messageIds) {
      final msgRef = _db.collection('threads').doc(threadId).collection('messages').doc(messageId);
      final doc = await msgRef.get();
      
      if (!doc.exists) continue;
      final data = doc.data();
      if (data == null) continue;
      
      // Only delete for everyone if the user is the sender
      if (data['fromUid'] == senderUid) {
        batch.update(msgRef, {
          'deletedForEveryone': true,
          'text': null,
          'ciphertextB64': null,
          'nonceB64': null,
          'macB64': null,
        });
        deletedCount++;
      }
    }
    
    await batch.commit();
    return deletedCount;
  }

  /// 📞 Sends a call message to record a voice call in the chat.
  /// 
  /// This is called when a voice call ends to show the call history in chat
  /// like WhatsApp does.
  /// 
  /// ✅ Call messages are marked as 'read' immediately since they are informational
  /// records and should not trigger unread message counts.
  Future<String> sendCallMessage({
    required String threadId,
    required String fromUid,
    required String toUid,
    required CallMessageStatus status,
    int? durationSeconds,
  }) async {
    final now = DateTime.now();
    final msgDoc = _db.collection('threads').doc(threadId).collection('messages').doc();
    
    await msgDoc.set({
      'fromUid': fromUid,
      'toUid': toUid,
      'messageType': 'call',
      'callStatus': status.name,
      'callDurationSeconds': durationSeconds,
      'sentAt': FieldValue.serverTimestamp(),
      'sentAtLocal': Timestamp.fromDate(now),
      'read': true, // ✅ Call messages are always marked as read (informational only)
      'status': 'read', // 🔕 Prevent unread badge for call history
    });

    await _db.collection('threads').doc(threadId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return msgDoc.id;
  }

  /// Sends a voice message to the chat.
  ///
  /// The audio file should already be uploaded to Cloudinary or Firebase Storage,
  /// and the URL passed here.
  Future<String> sendVoiceMessage({
    required String threadId,
    required String fromUid,
    required String toUid,
    required String voiceUrl,
    required int durationSeconds,
    String? replyToMessageId,
    String? replyToFromUid,
    String? replyToText,
  }) async {
    final now = DateTime.now();
    final msgDoc = _db.collection('threads').doc(threadId).collection('messages').doc();
    
    await msgDoc.set({
      'fromUid': fromUid,
      'toUid': toUid,
      'messageType': 'voice',
      'voiceUrl': voiceUrl,
      'voiceDurationSeconds': durationSeconds,
      'sentAt': FieldValue.serverTimestamp(),
      'sentAtLocal': Timestamp.fromDate(now),
      'replyToMessageId': replyToMessageId,
      'replyToFromUid': replyToFromUid,
      'replyToText': replyToText,
      'status': 'sent', // Message delivery status
    });

    await _db.collection('threads').doc(threadId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Best-effort notification
    try {
      await _notifications.create(
        toUid: toUid,
        fromUid: fromUid,
        type: NotificationType.message,
        threadId: threadId,
      );
    } catch (e) {
      // ignore
      print('Failed to create voice message notification: $e');
    }

    return msgDoc.id;
  }

  /// Stream that emits true if there are any unread messages across all threads for this user.
  /// 
  /// A message is considered unread if:
  /// - It was sent to this user (toUid == myUid)
  /// - It hasn't been marked as read
  /// Uses includeMetadataChanges to show cached data immediately when offline.
  Stream<bool> hasUnreadMessagesStream({required String myUid}) {
    return _db
        .collection('users')
        .doc(myUid)
        .collection('notifications')
        .where('type', isEqualTo: 'message')
        .where('read', isEqualTo: false)
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.isNotEmpty);
  }

  /// Stream of the last message for a specific thread.
  /// 
  /// Uses includeMetadataChanges to show cached data immediately when offline.
  Stream<FirestoreMessage?> lastMessageStream({required String threadId}) {
    return _db
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return FirestoreMessage.fromDoc(threadId: threadId, doc: snap.docs.first);
    });
  }

  /// 📬 Stream of unread message count for a specific thread.
  /// 
  /// Counts messages sent TO the current user that haven't been read.
  /// 📞 Excludes call and voice messages since they are informational only.
  /// Uses includeMetadataChanges to show cached data immediately when offline.
  Stream<int> unreadCountStream({required String threadId, required String myUid}) {
    // Query messages sent to me that are not yet read
    // Messages without 'read' field are considered unread
    return _db
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .where('toUid', isEqualTo: myUid)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          final unreadDocs = snap.docs.where((doc) {
            final data = doc.data();
            // 📞 Skip call messages - they don't count as unread
            final messageType = data['messageType'] as String?;
            if (messageType == 'call') return false;
            // 🎤 Skip voice messages from unread count too (optional - remove if you want voice to count)
            // if (messageType == 'voice') return false;
            // Message is unread if 'read' field doesn't exist or is false
            // Also check 'status' field for newer messages
            final isRead = data['read'] == true || data['status'] == 'read';
            return !isRead;
          });
          return unreadDocs.length;
        });
  }

  /// Marks all messages in a thread as read for the current user.
  /// 
  /// Call this when the user opens a chat thread.
  /// Updates both the 'read' field and the 'status' field to 'read'.
  Future<void> markThreadAsRead({required String threadId, required String myUid}) async {
    final messages = await _db
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .where('toUid', isEqualTo: myUid)
        .get();

    if (messages.docs.isEmpty) return;

    final batch = _db.batch();
    int updateCount = 0;
    for (final doc in messages.docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      final isRead = data['read'] as bool? ?? false;
      
      // Update if not already marked as read (handles old messages too)
      if (!isRead || status != 'read') {
        batch.update(doc.reference, {
          'read': true,
          'status': 'read', // Blue double tick
        });
        updateCount++;
      }
    }
    
    if (updateCount > 0) {
      await batch.commit();
    }
  }

  /// Marks all messages in a thread as delivered.
  /// 
  /// Call this when the recipient's device receives the messages.
  /// Only updates messages that are still in 'sent' status or have no status.
  Future<void> markMessagesAsDelivered({required String threadId, required String myUid}) async {
    final messages = await _db
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .where('toUid', isEqualTo: myUid)
        .get();

    if (messages.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in messages.docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      // Only update if status is 'sent' or null (old messages without status)
      if (status == null || status == 'sent') {
        batch.update(doc.reference, {'status': 'delivered'});
      }
    }
    await batch.commit();
  }

  /// Marks a single message as read.
  /// 
  /// Useful for marking individual messages as read.
  Future<void> markMessageAsRead({
    required String threadId,
    required String messageId,
  }) async {
    await _db
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .doc(messageId)
        .update({
          'read': true,
          'status': 'read',
        });
  }

  /// 🧹 Marks all call messages in a thread as read.
  /// 
  /// Call this to fix old call messages that were saved without read:true.
  /// This is a one-time cleanup for existing data.
  Future<void> markCallMessagesAsRead({required String threadId}) async {
    final messages = await _db
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .where('messageType', isEqualTo: 'call')
        .get();

    if (messages.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in messages.docs) {
      final data = doc.data();
      final isRead = data['read'] as bool? ?? false;
      if (!isRead) {
        batch.update(doc.reference, {
          'read': true,
          'status': 'read',
        });
      }
    }
    await batch.commit();
  }

  /// Get a thread by ID, preferring cache for instant loading.
  /// 
  /// Uses GetOptions.source to try cache first, then fall back to server.
  Future<FirestoreChatThread?> getThreadByIdCached(String threadId) async {
    try {
      // Try cache first for instant loading
      final doc = await _db.collection('threads').doc(threadId).get(
        const GetOptions(source: Source.cache),
      );
      final data = doc.data();
      if (data != null) {
        return FirestoreChatThread(
          id: doc.id,
          userAUid: data['userAUid'] as String,
          userBUid: data['userBUid'] as String,
          userAEmail: (data['userAEmail'] as String?) ?? '',
          userBEmail: (data['userBEmail'] as String?) ?? '',
          lastMessageAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        );
      }
    } catch (_) {
      // Cache miss, fall through to server
    }

    // Fall back to server
    return getThreadById(threadId);
  }
}
