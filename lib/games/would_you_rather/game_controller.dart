import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_models.dart';
import 'questions.dart';

class WouldYouRatherController {
  final _firestore = FirebaseFirestore.instance;

  // Collection references
  DocumentReference get _gameDoc => _firestore.collection('games').doc('would_you_rather');
  CollectionReference<Map<String, dynamic>> get _sessionsRef => _gameDoc.collection('sessions');
  CollectionReference<Map<String, dynamic>> get _matchmakingRef => _gameDoc.collection('matchmaking_queue');

  CollectionReference<Map<String, dynamic>> _answersRef(String sessionId) =>
      _sessionsRef.doc(sessionId).collection('answers');

  // ============ SESSION MANAGEMENT ============

  /// Create a new game session (for inviting a friend or starting matchmaking)
  Future<WouldYouRatherSession> createSession({
    required String hostUid,
    required String hostName,
    String? hostImageB64,
    bool isMatchmaking = false,
  }) async {
    final questionIds = getRandomQuestionIds(count: 8);
    final now = DateTime.now();
    
    final docRef = _sessionsRef.doc();
    final session = WouldYouRatherSession(
      id: docRef.id,
      player1Uid: hostUid,
      player1Name: hostName,
      player1ImageB64: hostImageB64,
      status: SessionStatus.waiting,
      questionIds: questionIds,
      currentQuestionIndex: 0,
      createdAt: now,
    );

    await docRef.set(session.toMap());

    // If matchmaking, add to queue
    if (isMatchmaking) {
      await _matchmakingRef.doc(hostUid).set({
        'sessionId': session.id,
        'uid': hostUid,
        'name': hostName,
        'imageB64': hostImageB64,
        'createdAt': now.toIso8601String(),
      });
    }

    return session;
  }

  /// Join an existing session (for accepting invite or matchmaking)
  Future<WouldYouRatherSession?> joinSession({
    required String sessionId,
    required String joinerUid,
    required String joinerName,
    String? joinerImageB64,
  }) async {
    final docRef = _sessionsRef.doc(sessionId);
    
    return _firestore.runTransaction<WouldYouRatherSession?>((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return null;

      final session = WouldYouRatherSession.fromMap(doc.data()!, doc.id);
      
      // Can't join if already full or not waiting
      if (session.isFull || session.status != SessionStatus.waiting) {
        return null;
      }

      // Can't join own session
      if (session.player1Uid == joinerUid) {
        return null;
      }

      final now = DateTime.now();
      final updatedSession = session.copyWith(
        player2Uid: joinerUid,
        player2Name: joinerName,
        player2ImageB64: joinerImageB64,
        status: SessionStatus.playing,
        questionStartedAt: now,
      );

      transaction.update(docRef, {
        'player2Uid': joinerUid,
        'player2Name': joinerName,
        'player2ImageB64': joinerImageB64,
        'status': SessionStatus.playing.name,
        'questionStartedAt': now.toIso8601String(),
      });

      return updatedSession;
    });
  }

  /// Find a random match from the queue
  Future<WouldYouRatherSession?> findRandomMatch({
    required String uid,
    required String name,
    String? imageB64,
  }) async {
    // First, check if there's anyone in the queue (not ourselves)
    final queueSnap = await _matchmakingRef
        .where('uid', isNotEqualTo: uid)
        .orderBy('uid')
        .orderBy('createdAt')
        .limit(1)
        .get();

    if (queueSnap.docs.isEmpty) {
      // No one in queue, create session and wait
      return createSession(
        hostUid: uid,
        hostName: name,
        hostImageB64: imageB64,
        isMatchmaking: true,
      );
    }

    // Try to join the first available session
    final matchData = queueSnap.docs.first.data();
    final sessionId = matchData['sessionId'] as String;
    final matchedUid = matchData['uid'] as String;

    final session = await joinSession(
      sessionId: sessionId,
      joinerUid: uid,
      joinerName: name,
      joinerImageB64: imageB64,
    );

    if (session != null) {
      // Successfully joined, remove both from queue
      await _matchmakingRef.doc(matchedUid).delete();
      await _matchmakingRef.doc(uid).delete();
    }

    return session;
  }

  /// Cancel matchmaking
  Future<void> cancelMatchmaking(String uid) async {
    // Get user's queue entry
    final queueDoc = await _matchmakingRef.doc(uid).get();
    if (queueDoc.exists) {
      final sessionId = queueDoc.data()?['sessionId'] as String?;
      
      // Delete queue entry
      await _matchmakingRef.doc(uid).delete();
      
      // Cancel the session
      if (sessionId != null) {
        await _sessionsRef.doc(sessionId).update({
          'status': SessionStatus.cancelled.name,
        });
      }
    }
  }

  /// Leave/cancel a session
  Future<void> leaveSession(String sessionId, String uid) async {
    await _sessionsRef.doc(sessionId).update({
      'status': SessionStatus.cancelled.name,
    });
  }

  // ============ GAMEPLAY ============

  /// Submit an answer for the current question
  Future<void> submitAnswer({
    required String sessionId,
    required String playerUid,
    required String questionId,
    required String choice,
  }) async {
    final answerId = '${playerUid}_$questionId';
    final answer = WouldYouRatherAnswer(
      sessionId: sessionId,
      playerUid: playerUid,
      questionId: questionId,
      choice: choice,
      answeredAt: DateTime.now(),
    );

    await _answersRef(sessionId).doc(answerId).set(answer.toMap());
  }

  /// Get answers for a specific question
  Future<Map<String, String>> getAnswersForQuestion({
    required String sessionId,
    required String questionId,
  }) async {
    final snap = await _answersRef(sessionId)
        .where('questionId', isEqualTo: questionId)
        .get();

    return {
      for (final doc in snap.docs)
        doc.data()['playerUid'] as String: doc.data()['choice'] as String
    };
  }

  /// Check if both players answered current question
  Future<bool> bothPlayersAnswered({
    required String sessionId,
    required String questionId,
    required String player1Uid,
    required String player2Uid,
  }) async {
    final answers = await getAnswersForQuestion(
      sessionId: sessionId,
      questionId: questionId,
    );
    return answers.containsKey(player1Uid) && answers.containsKey(player2Uid);
  }

  /// Move to next question or finish game
  Future<void> advanceToNextQuestion({
    required String sessionId,
    required int currentIndex,
    required int totalQuestions,
    required String questionId,
    required String player1Uid,
    required String player2Uid,
  }) async {
    // Calculate if answers matched
    final answers = await getAnswersForQuestion(
      sessionId: sessionId,
      questionId: questionId,
    );
    
    final player1Choice = answers[player1Uid];
    final player2Choice = answers[player2Uid];
    final isMatch = player1Choice != null && 
                    player2Choice != null && 
                    player1Choice == player2Choice;

    final nextIndex = currentIndex + 1;
    final isFinished = nextIndex >= totalQuestions;

    await _sessionsRef.doc(sessionId).update({
      'currentQuestionIndex': nextIndex,
      'questionStartedAt': isFinished ? null : DateTime.now().toIso8601String(),
      'status': isFinished ? SessionStatus.finished.name : SessionStatus.playing.name,
      'matches': FieldValue.increment(isMatch ? 1 : 0),
      'totalAnswered': FieldValue.increment(1),
    });
  }

  /// Skip current question (timeout)
  Future<void> skipQuestion({
    required String sessionId,
    required int currentIndex,
    required int totalQuestions,
  }) async {
    final nextIndex = currentIndex + 1;
    final isFinished = nextIndex >= totalQuestions;

    await _sessionsRef.doc(sessionId).update({
      'currentQuestionIndex': nextIndex,
      'questionStartedAt': isFinished ? null : DateTime.now().toIso8601String(),
      'status': isFinished ? SessionStatus.finished.name : SessionStatus.playing.name,
      'totalAnswered': FieldValue.increment(1),
    });
  }

  // ============ REAL-TIME STREAMS ============

  /// Stream session updates
  Stream<WouldYouRatherSession?> streamSession(String sessionId) {
    return _sessionsRef.doc(sessionId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return WouldYouRatherSession.fromMap(doc.data()!, doc.id);
    });
  }

  /// Stream answers for a question
  Stream<Map<String, String>> streamAnswersForQuestion({
    required String sessionId,
    required String questionId,
  }) {
    return _answersRef(sessionId)
        .where('questionId', isEqualTo: questionId)
        .snapshots()
        .map((snap) => {
          for (final doc in snap.docs)
            doc.data()['playerUid'] as String: doc.data()['choice'] as String
        });
  }

  /// Stream matchmaking queue for user's session
  Stream<WouldYouRatherSession?> streamUserSession(String uid) {
    return _sessionsRef
        .where('player1Uid', isEqualTo: uid)
        .where('status', isEqualTo: SessionStatus.waiting.name)
        .limit(1)
        .snapshots()
        .asyncMap((snap) async {
          if (snap.docs.isEmpty) {
            // Check if user joined as player2
            final asPlayer2 = await _sessionsRef
                .where('player2Uid', isEqualTo: uid)
                .where('status', whereIn: [SessionStatus.waiting.name, SessionStatus.playing.name])
                .limit(1)
                .get();
            if (asPlayer2.docs.isNotEmpty) {
              return WouldYouRatherSession.fromMap(
                asPlayer2.docs.first.data(),
                asPlayer2.docs.first.id,
              );
            }
            return null;
          }
          return WouldYouRatherSession.fromMap(
            snap.docs.first.data(),
            snap.docs.first.id,
          );
        });
  }

  // ============ RESULTS ============

  /// Get all answers for a session
  Future<List<WouldYouRatherAnswer>> getAllAnswers(String sessionId) async {
    final snap = await _answersRef(sessionId).get();
    return snap.docs.map((d) => WouldYouRatherAnswer.fromMap(d.data())).toList();
  }

  /// Build complete game result
  Future<WouldYouRatherResult> getGameResult({
    required WouldYouRatherSession session,
  }) async {
    final answers = await getAllAnswers(session.id);
    final questions = getQuestionsByIds(session.questionIds);

    final questionResults = <QuestionResult>[];

    for (final question in questions) {
      final p1Answer = answers.where(
        (a) => a.questionId == question.id && a.playerUid == session.player1Uid
      ).firstOrNull;
      final p2Answer = answers.where(
        (a) => a.questionId == question.id && a.playerUid == session.player2Uid
      ).firstOrNull;

      questionResults.add(QuestionResult(
        question: question,
        player1Choice: p1Answer?.choice,
        player2Choice: p2Answer?.choice,
      ));
    }

    return WouldYouRatherResult(
      session: session,
      questionResults: questionResults,
    );
  }

  /// Get session by ID
  Future<WouldYouRatherSession?> getSession(String sessionId) async {
    final doc = await _sessionsRef.doc(sessionId).get();
    if (!doc.exists) return null;
    return WouldYouRatherSession.fromMap(doc.data()!, doc.id);
  }

  // ============ INVITE SYSTEM ============

  /// Generate invite link/code for a session
  String getInviteCode(String sessionId) => sessionId;

  /// Join via invite code
  Future<WouldYouRatherSession?> joinViaInvite({
    required String inviteCode,
    required String joinerUid,
    required String joinerName,
    String? joinerImageB64,
  }) async {
    return joinSession(
      sessionId: inviteCode,
      joinerUid: joinerUid,
      joinerName: joinerName,
      joinerImageB64: joinerImageB64,
    );
  }
}
