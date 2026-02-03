import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../notifications/firestore_notifications_controller.dart';
import '../notifications/notification_models.dart';

/// Firestore-backed friend requests + friends list.
///
/// Schema:
/// friend_requests/{requestId}
///   fromUid, toUid, status(pending/accepted/declined/cancelled), createdAt, updatedAt
/// users/{uid}/friends/{friendUid}
///   friendUid, createdAt
@immutable
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final String status;

  static FriendRequest fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FriendRequest(
      id: doc.id,
      fromUid: d['fromUid'] as String,
      toUid: d['toUid'] as String,
      status: d['status'] as String,
    );
  }
}

@immutable
class FriendStatus {
  const FriendStatus({
    required this.areFriends,
    required this.hasOutgoingRequest,
    required this.hasIncomingRequest,
  });

  final bool areFriends;
  final bool hasOutgoingRequest;
  final bool hasIncomingRequest;
}

class FirestoreSocialGraphController {
  FirestoreSocialGraphController({
    FirebaseFirestore? firestore,
    FirestoreNotificationsController? notifications,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _notifications = notifications ?? FirestoreNotificationsController(firestore: firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _db;
  final FirestoreNotificationsController _notifications;

  /// Deterministic request id for a pair (from -> to). Prevents duplicates.
  String requestId(String fromUid, String toUid) => '$fromUid->$toUid';

  Stream<Set<String>> friendsStream({required String uid}) {
    return _db.collection('users').doc(uid).collection('friends').snapshots().map(
          (snap) => snap.docs.map((d) => d.id).toSet(),
        );
  }

  Stream<List<FriendRequest>> incomingRequestsStream({required String uid}) {
    return _db
        .collection('friend_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FriendRequest.fromDoc(d)).toList(growable: false));
  }

  Stream<List<FriendRequest>> outgoingRequestsStream({required String uid}) {
    return _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FriendRequest.fromDoc(d)).toList(growable: false));
  }

  Future<bool> areFriends({required String aUid, required String bUid}) async {
    final doc = await _db.collection('users').doc(aUid).collection('friends').doc(bUid).get();
    return doc.exists;
  }

  Future<bool> hasOutgoingRequest({required String fromUid, required String toUid}) async {
    final doc = await _db.collection('friend_requests').doc(requestId(fromUid, toUid)).get();
    return doc.exists && (doc.data()?['status'] == 'pending');
  }

  Future<bool> hasIncomingRequest({required String toUid, required String fromUid}) async {
    final doc = await _db.collection('friend_requests').doc(requestId(fromUid, toUid)).get();
    return doc.exists && (doc.data()?['status'] == 'pending');
  }

  Future<void> sendRequest({required String fromUid, required String toUid}) async {
    if (fromUid == toUid) return;

    final id = requestId(fromUid, toUid);
    final ref = _db.collection('friend_requests').doc(id);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) {
        final status = existing.data()?['status'];
        if (status == 'pending') return;
      }

      tx.set(ref, {
        'fromUid': fromUid,
        'toUid': toUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _notifications.create(
      toUid: toUid,
      fromUid: fromUid,
      type: NotificationType.friendRequestSent,
    );
  }

  Future<void> cancelOutgoing({required String fromUid, required String toUid}) async {
    final ref = _db.collection('friend_requests').doc(requestId(fromUid, toUid));
    await ref.set({'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    await _notifications.create(
      toUid: toUid,
      fromUid: fromUid,
      type: NotificationType.friendRequestCancelled,
    );
  }

  Future<void> declineIncoming({required String toUid, required String fromUid}) async {
    final ref = _db.collection('friend_requests').doc(requestId(fromUid, toUid));
    await ref.set({'status': 'declined', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    await _notifications.create(
      toUid: fromUid,
      fromUid: toUid,
      type: NotificationType.friendRequestDeclined,
    );
  }

  Future<void> acceptIncoming({required String toUid, required String fromUid}) async {
    final reqRef = _db.collection('friend_requests').doc(requestId(fromUid, toUid));
    final aRef = _db.collection('users').doc(toUid).collection('friends').doc(fromUid);
    final bRef = _db.collection('users').doc(fromUid).collection('friends').doc(toUid);

    await _db.runTransaction((tx) async {
      final req = await tx.get(reqRef);
      if (!req.exists) return;
      final status = req.data()?['status'];
      if (status != 'pending') return;

      tx.set(reqRef, {'status': 'accepted', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.set(aRef, {'friendUid': fromUid, 'createdAt': FieldValue.serverTimestamp()});
      tx.set(bRef, {'friendUid': toUid, 'createdAt': FieldValue.serverTimestamp()});
    });

    await _notifications.create(
      toUid: fromUid,
      fromUid: toUid,
      type: NotificationType.friendRequestAccepted,
    );
  }

  Stream<FriendStatus> friendStatusStream({required String myUid, required String otherUid}) {
    final controller = StreamController<FriendStatus>();

    Set<String>? friends;
    List<FriendRequest>? incoming;
    List<FriendRequest>? outgoing;

    void emit() {
      if (friends == null || incoming == null || outgoing == null) return;
      final areFriends = friends!.contains(otherUid);
      final hasIncoming = incoming!.any((r) => r.fromUid == otherUid && r.toUid == myUid);
      final hasOutgoing = outgoing!.any((r) => r.fromUid == myUid && r.toUid == otherUid);
      controller.add(
        FriendStatus(
          areFriends: areFriends,
          hasIncomingRequest: hasIncoming,
          hasOutgoingRequest: hasOutgoing,
        ),
      );
    }

    late final StreamSubscription subFriends;
    late final StreamSubscription subIn;
    late final StreamSubscription subOut;

    subFriends = friendsStream(uid: myUid).listen((v) {
      friends = v;
      emit();
    }, onError: controller.addError);

    subIn = incomingRequestsStream(uid: myUid).listen((v) {
      incoming = v;
      emit();
    }, onError: controller.addError);

    subOut = outgoingRequestsStream(uid: myUid).listen((v) {
      outgoing = v;
      emit();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await subFriends.cancel();
      await subIn.cancel();
      await subOut.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Future<int> friendsCount({required String uid}) async {
    final snap = await _db.collection('users').doc(uid).collection('friends').get();
    return snap.size;
  }
}
