import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../chat/firestore_chat_controller.dart';
import '../notifications/firestore_notifications_controller.dart';
import '../notifications/notification_models.dart';

/// Firestore-backed friend requests + friends list + lightweight match requests.
///
/// NOTE: This match implementation is client-driven (no Cloud Functions). For a
/// production one-match-only constraint, move match mutations to Cloud
/// Functions/Callable endpoints with Admin SDK transactions.
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

enum SwipeDecision { match, friend, skip }

enum MatchRequestStatus { pending, accepted, declined, cancelled }

@immutable
class MatchRequest {
  const MatchRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final String status;

  static MatchRequest fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return MatchRequest(
      id: doc.id,
      fromUid: d['fromUid'] as String,
      toUid: d['toUid'] as String,
      status: d['status'] as String,
    );
  }
}

/// Represents a match (current or past) between two users.
/// Match history is public - everyone can see who matched with whom.
@immutable
class Match {
  const Match({
    required this.id,
    required this.userAUid,
    required this.userBUid,
    required this.state,
    required this.requestedByUid,
    this.requestedAt,
    this.matchedAt,
    this.brokenAt,
    this.breakupInitiatedByUid,
    this.coupleThreadId,
  });

  final String id;
  final String userAUid;
  final String userBUid;
  final String state; // 'matched' or 'broken'
  final String requestedByUid;
  final DateTime? requestedAt;
  final DateTime? matchedAt;
  final DateTime? brokenAt;
  final String? breakupInitiatedByUid;
  final String? coupleThreadId;

  bool get isActive => state == 'matched';
  bool get isBroken => state == 'broken';

  /// Returns the other user's UID given one user's UID.
  String otherUid(String myUid) => myUid == userAUid ? userBUid : userAUid;

  /// Check if a user is part of this match.
  bool involves(String uid) => userAUid == uid || userBUid == uid;

  static Match fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Match(
      id: doc.id,
      userAUid: d['userAUid'] as String,
      userBUid: d['userBUid'] as String,
      state: d['state'] as String? ?? 'matched',
      requestedByUid: d['requestedByUid'] as String,
      requestedAt: (d['requestedAt'] as Timestamp?)?.toDate(),
      matchedAt: (d['matchedAt'] as Timestamp?)?.toDate(),
      brokenAt: (d['brokenAt'] as Timestamp?)?.toDate(),
      breakupInitiatedByUid: d['breakupInitiatedByUid'] as String?,
      coupleThreadId: d['coupleThreadId'] as String?,
    );
  }
}

class FirestoreSocialGraphController {
  FirestoreSocialGraphController({
    FirebaseFirestore? firestore,
    FirestoreNotificationsController? notifications,
    FirestoreChatController? chat,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _notifications = notifications ?? FirestoreNotificationsController(firestore: firestore ?? FirebaseFirestore.instance),
        _chat = chat;

  final FirestoreChatController? _chat;

  final FirebaseFirestore _db;
  final FirestoreNotificationsController _notifications;

  /// Deterministic request id for a pair (from -> to). Prevents duplicates.
  String requestId(String fromUid, String toUid) => '$fromUid->$toUid';

  String matchRequestId(String fromUid, String toUid) => '$fromUid->$toUid';

  Stream<Set<String>> friendsStream({required String uid}) {
    return _db.collection('users').doc(uid).collection('friends')
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  Stream<List<FriendRequest>> incomingRequestsStream({required String uid}) {
    return _db
        .collection('friend_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.map((d) => FriendRequest.fromDoc(d)).toList(growable: false));
  }

  // outgoingRequestsStream is defined below (friend requests).

  Stream<List<MatchRequest>> incomingMatchRequestsStream({required String uid}) {
    return _db
        .collection('match_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.map((d) => MatchRequest.fromDoc(d)).toList(growable: false));
  }

  Stream<List<MatchRequest>> outgoingMatchRequestsStream({required String uid}) {
    return _db
        .collection('match_requests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.map((d) => MatchRequest.fromDoc(d)).toList(growable: false));
  }

  Future<void> recordSwipe({
    required String uid,
    required String otherUid,
    required SwipeDecision decision,
  }) async {
    if (uid == otherUid) return;
    await _db.collection('users').doc(uid).collection('swipes').doc(otherUid).set({
      'otherUid': otherUid,
      'decision': decision.name,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Set<String>> swipedUids({required String uid}) async {
    final snap = await _db.collection('users').doc(uid).collection('swipes').get();
    return snap.docs.map((d) => d.id).toSet();
  }

  Future<void> sendMatchRequest({required String fromUid, required String toUid}) async {
    if (fromUid == toUid) return;

    final fromRef = _db.collection('users').doc(fromUid);
    final toRef = _db.collection('users').doc(toUid);
    final reqRef = _db.collection('match_requests').doc(matchRequestId(fromUid, toUid));

    // Check if request already exists (outside transaction to avoid permission issues)
    try {
      final existingReq = await reqRef.get();
      if (existingReq.exists && existingReq.data()?['status'] == 'pending') {
        // Request already pending, no need to create again
        return;
      }
    } catch (_) {
      // Document may not exist or we may not have permission to read - that's fine, proceed
    }

    // Check user states outside transaction
    final fromSnap = await fromRef.get();
    final toSnap = await toRef.get();
    
    if (!fromSnap.exists || !toSnap.exists) return;

    final from = fromSnap.data() as Map<String, dynamic>;
    final to = toSnap.data() as Map<String, dynamic>;

    // Soft one-match constraint (client-driven). For strict enforcement use Cloud Functions.
    if ((from['activeMatchWithUid'] as String?) != null) {
      throw StateError('You already have a match. Break it before requesting a new one.');
    }
    if ((to['activeMatchWithUid'] as String?) != null) {
      // Target is currently matched - silently return
      return;
    }

    // Create the match request
    await reqRef.set({
      'fromUid': fromUid,
      'toUid': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _notifications.create(
      toUid: toUid,
      fromUid: fromUid,
      type: NotificationType.friendRequestSent, // reuse for now; consider a new type
    );
  }

  Future<void> acceptMatchRequest({required String toUid, required String fromUid}) async {
    final reqRef = _db.collection('match_requests').doc(matchRequestId(fromUid, toUid));
    final matchRef = _db.collection('matches').doc();

    final aRef = _db.collection('users').doc(fromUid);
    final bRef = _db.collection('users').doc(toUid);

    // Create couple thread outside transaction (Firestore doesn't allow creating
    // arbitrary docs with generated ids inside security-limited transactions).
    final aSnap = await aRef.get();
    final bSnap = await bRef.get();
    final aEmail = (aSnap.data()?['email'] as String?) ?? '';
    final bEmail = (bSnap.data()?['email'] as String?) ?? '';

    final chat = _chat;
    if (chat == null) {
      throw StateError('Chat controller not configured');
    }

    final coupleThread = await chat.createCoupleThread(
      uidA: fromUid,
      emailA: aEmail,
      uidB: toUid,
      emailB: bEmail,
      matchId: matchRef.id,
    );

    await _db.runTransaction((tx) async {
      final req = await tx.get(reqRef);
      if (!req.exists) return;
      if (req.data()?['status'] != 'pending') return;

      final aSnap = await tx.get(aRef);
      final bSnap = await tx.get(bRef);
      if (!aSnap.exists || !bSnap.exists) return;

      final a = aSnap.data() as Map<String, dynamic>;
      final b = bSnap.data() as Map<String, dynamic>;

      if ((a['activeMatchWithUid'] as String?) != null || (b['activeMatchWithUid'] as String?) != null) {
        throw StateError('One of the users is already matched.');
      }

      tx.set(reqRef, {'status': 'accepted', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

      tx.set(matchRef, {
        'userAUid': fromUid,
        'userBUid': toUid,
        'state': 'matched',
        'requestedByUid': fromUid,
        'requestedAt': req.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'matchedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'coupleThreadId': coupleThread.id,
      });

      // Write match pointers (used by UI + pinned match).
      tx.set(aRef, {
        'activeMatchId': matchRef.id,
        'activeMatchWithUid': toUid,
        'activeCoupleThreadId': coupleThread.id,
        'matchState': 'matched',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(bRef, {
        'activeMatchId': matchRef.id,
        'activeMatchWithUid': fromUid,
        'activeCoupleThreadId': coupleThread.id,
        'matchState': 'matched',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> declineMatchRequest({required String toUid, required String fromUid}) async {
    final ref = _db.collection('match_requests').doc(matchRequestId(fromUid, toUid));
    await ref.set({'status': 'declined', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> cancelOutgoingMatchRequest({required String fromUid, required String toUid}) async {
    final ref = _db.collection('match_requests').doc(matchRequestId(fromUid, toUid));
    await ref.set({'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> breakMatch({required String uid}) async {
    final userRef = _db.collection('users').doc(uid);

    String? matchId;
    String? otherUid;
    String? coupleThreadId;

    // 1) Clear pointers in a transaction (revokes access immediately via rules).
    await _db.runTransaction((tx) async {
      final me = await tx.get(userRef);
      final data = me.data();
      matchId = data?['activeMatchId'] as String?;
      otherUid = data?['activeMatchWithUid'] as String?;
      coupleThreadId = data?['activeCoupleThreadId'] as String?;
      if (matchId == null || otherUid == null) return;

      final otherRef = _db.collection('users').doc(otherUid!);
      final matchRef = _db.collection('matches').doc(matchId!);

      tx.set(matchRef, {
        'state': 'broken',
        'breakupInitiatedByUid': uid,
        'breakupConfirmedByUid': uid,
        'brokenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(userRef, {
        'activeMatchId': null,
        'activeMatchWithUid': null,
        'activeCoupleThreadId': null,
        'matchState': 'single',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(otherRef, {
        'activeMatchId': null,
        'activeMatchWithUid': null,
        'activeCoupleThreadId': null,
        'matchState': 'single',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    final tid = coupleThreadId;
    if (tid == null || tid.isEmpty) return;

    // 2) Prefer Cloud Function for guaranteed recursive delete.
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteThreadRecursive');
      await callable.call({'threadId': tid});
      return;
    } catch (_) {
      // Fall back to best-effort client-side deletion.
    }

    final msgs = _db.collection('threads').doc(tid).collection('messages');
    while (true) {
      final batchSnap = await msgs.orderBy('sentAt').limit(200).get();
      if (batchSnap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in batchSnap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }

    await _db.collection('threads').doc(tid).delete();
  }

  Stream<List<FriendRequest>> outgoingRequestsStream({required String uid}) {
    return _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
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

  /// Fetches the set of friends for a user (one-time fetch, not a stream).
  Future<Set<String>> getFriends({required String uid}) async {
    final snap = await _db.collection('users').doc(uid).collection('friends').get();
    return snap.docs.map((d) => d.id).toSet();
  }

  /// Fetches friends of friends (people your friends are friends with).
  /// Returns a map of uid -> list of mutual friend uids (friends who connect you).
  Future<Map<String, List<String>>> getFriendsOfFriends({required String uid}) async {
    final myFriends = await getFriends(uid: uid);
    if (myFriends.isEmpty) return {};

    final friendsOfFriends = <String, List<String>>{};

    // Fetch friends of each friend
    for (final friendUid in myFriends) {
      final theirFriends = await getFriends(uid: friendUid);
      for (final fofUid in theirFriends) {
        // Exclude self and direct friends
        if (fofUid == uid || myFriends.contains(fofUid)) continue;
        
        friendsOfFriends.putIfAbsent(fofUid, () => []);
        friendsOfFriends[fofUid]!.add(friendUid);
      }
    }

    return friendsOfFriends;
  }

  // =====================================================
  // MATCH HISTORY (Public - visible to everyone)
  // =====================================================

  /// Stream all matches (current and past) for a user.
  /// This is PUBLIC - anyone can view anyone's match history.
  Stream<List<Match>> matchHistoryStream({required String uid}) {
    // Query matches where user is either userA or userB
    // We need two queries and merge them
    final streamA = _db
        .collection('matches')
        .where('userAUid', isEqualTo: uid)
        .orderBy('matchedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Match.fromDoc(d)).toList());

    final streamB = _db
        .collection('matches')
        .where('userBUid', isEqualTo: uid)
        .orderBy('matchedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Match.fromDoc(d)).toList());

    // Combine both streams
    return streamA.asyncExpand((listA) {
      return streamB.map((listB) {
        final combined = <Match>[...listA, ...listB];
        // Sort by matchedAt descending, active matches first
        combined.sort((a, b) {
          // Active matches come first
          if (a.isActive && !b.isActive) return -1;
          if (!a.isActive && b.isActive) return 1;
          // Then by date
          final aDate = a.matchedAt ?? DateTime(1970);
          final bDate = b.matchedAt ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
        return combined;
      });
    });
  }

  /// Get current active match for a user (if any).
  Future<Match?> getCurrentMatch({required String uid}) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    final data = userDoc.data();
    final activeMatchId = data?['activeMatchId'] as String?;
    
    if (activeMatchId == null || activeMatchId.isEmpty) return null;
    
    final matchDoc = await _db.collection('matches').doc(activeMatchId).get();
    if (!matchDoc.exists) return null;
    
    return Match.fromDoc(matchDoc);
  }

  /// Stream the current active match for a user.
  Stream<Match?> currentMatchStream({required String uid}) {
    return _db.collection('users').doc(uid).snapshots().asyncMap((userSnap) async {
      final data = userSnap.data();
      final activeMatchId = data?['activeMatchId'] as String?;
      
      if (activeMatchId == null || activeMatchId.isEmpty) return null;
      
      final matchDoc = await _db.collection('matches').doc(activeMatchId).get();
      if (!matchDoc.exists) return null;
      
      return Match.fromDoc(matchDoc);
    });
  }

  /// Check if user is currently matched (has an active match).
  Future<bool> isCurrentlyMatched({required String uid}) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    final data = userDoc.data();
    return (data?['activeMatchWithUid'] as String?) != null;
  }

  /// Get the UID of the user's current match partner (if any).
  Future<String?> getCurrentMatchPartnerUid({required String uid}) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    final data = userDoc.data();
    return data?['activeMatchWithUid'] as String?;
  }

  /// Stream match status between current user and another user.
  /// Returns information about their match relationship.
  Stream<MatchStatus> matchStatusStream({required String myUid, required String otherUid}) {
    final controller = StreamController<MatchStatus>();

    Match? currentMatch;
    List<MatchRequest>? incomingRequests;
    List<MatchRequest>? outgoingRequests;
    String? myActiveMatchWithUid;
    String? otherActiveMatchWithUid;

    void emit() {
      if (incomingRequests == null || outgoingRequests == null) return;

      final hasIncoming = incomingRequests!.any((r) => r.fromUid == otherUid && r.toUid == myUid);
      final hasOutgoing = outgoingRequests!.any((r) => r.fromUid == myUid && r.toUid == otherUid);
      final areMatched = currentMatch != null && currentMatch!.isActive && currentMatch!.involves(otherUid);
      final iAmMatched = myActiveMatchWithUid != null;
      final theyAreMatched = otherActiveMatchWithUid != null;

      controller.add(MatchStatus(
        areMatched: areMatched,
        hasOutgoingRequest: hasOutgoing,
        hasIncomingRequest: hasIncoming,
        iAmAlreadyMatched: iAmMatched && !areMatched,
        theyAreAlreadyMatched: theyAreMatched && !areMatched,
        myMatchPartnerUid: myActiveMatchWithUid,
        theirMatchPartnerUid: otherActiveMatchWithUid,
      ));
    }

    late final StreamSubscription subMatch;
    late final StreamSubscription subIn;
    late final StreamSubscription subOut;
    late final StreamSubscription subMyUser;
    late final StreamSubscription subOtherUser;

    subMatch = currentMatchStream(uid: myUid).listen((m) {
      currentMatch = m;
      emit();
    }, onError: controller.addError);

    subIn = incomingMatchRequestsStream(uid: myUid).listen((v) {
      incomingRequests = v;
      emit();
    }, onError: controller.addError);

    subOut = outgoingMatchRequestsStream(uid: myUid).listen((v) {
      outgoingRequests = v;
      emit();
    }, onError: controller.addError);

    subMyUser = _db.collection('users').doc(myUid).snapshots().listen((snap) {
      myActiveMatchWithUid = snap.data()?['activeMatchWithUid'] as String?;
      emit();
    }, onError: controller.addError);

    subOtherUser = _db.collection('users').doc(otherUid).snapshots().listen((snap) {
      otherActiveMatchWithUid = snap.data()?['activeMatchWithUid'] as String?;
      emit();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await subMatch.cancel();
      await subIn.cancel();
      await subOut.cancel();
      await subMyUser.cancel();
      await subOtherUser.cancel();
      await controller.close();
    };

    return controller.stream;
  }
}

/// Status of match relationship between two users.
@immutable
class MatchStatus {
  const MatchStatus({
    required this.areMatched,
    required this.hasOutgoingRequest,
    required this.hasIncomingRequest,
    required this.iAmAlreadyMatched,
    required this.theyAreAlreadyMatched,
    this.myMatchPartnerUid,
    this.theirMatchPartnerUid,
  });

  final bool areMatched;
  final bool hasOutgoingRequest;
  final bool hasIncomingRequest;
  final bool iAmAlreadyMatched; // I have a match with someone else
  final bool theyAreAlreadyMatched; // They have a match with someone else
  final String? myMatchPartnerUid;
  final String? theirMatchPartnerUid;
}
