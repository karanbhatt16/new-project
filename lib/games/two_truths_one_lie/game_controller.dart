import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_models.dart';

/// Controller for "Two Truths & One Lie" game data operations.
class TwoTruthsController {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _publicSubmissionsRef =>
      _firestore.collection('games').doc('two_truths_one_lie').collection('public_submissions');
  CollectionReference<Map<String, dynamic>> get _privateSubmissionsRef =>
      _firestore.collection('games').doc('two_truths_one_lie').collection('private_submissions');

  CollectionReference<Map<String, dynamic>> get _guessesRef =>
      _firestore.collection('games').doc('two_truths_one_lie').collection('guesses');

  CollectionReference<Map<String, dynamic>> get _leaderboardRef =>
      _firestore.collection('games').doc('two_truths_one_lie').collection('leaderboard');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Check if user has already submitted their statements.
  Future<bool> hasSubmitted(String uid) async {
    final doc = await _publicSubmissionsRef.doc(uid).get();
    return doc.exists;
  }

  /// Get user's public submission (statements only).
  Future<TwoTruthsSubmission?> getSubmission(String uid) async {
    final publicDoc = await _publicSubmissionsRef.doc(uid).get();
    if (!publicDoc.exists) return null;
    final data = publicDoc.data()!;
    // lieIndex is stored privately; set to -1 for public shape
    return TwoTruthsSubmission(
      uid: data['uid'] as String,
      statement1: data['statement1'] as String,
      statement2: data['statement2'] as String,
      statement3: data['statement3'] as String,
      lieIndex: -1,
      submittedAt: DateTime.parse(data['submittedAt'] as String),
    );
  }

  /// Get my private lie index.
  Future<int?> getMyLieIndex(String uid) async {
    final privateDoc = await _privateSubmissionsRef.doc(uid).get();
    if (!privateDoc.exists) return null;
    return privateDoc.data()!['lieIndex'] as int;
  }

  /// Submit two truths and one lie.
  Future<void> submitStatements({
    required String uid,
    required String statement1,
    required String statement2,
    required String statement3,
    required int lieIndex,
  }) async {
    final now = DateTime.now();

    // Public document (no lie index)
    await _publicSubmissionsRef.doc(uid).set({
      'uid': uid,
      'statement1': statement1,
      'statement2': statement2,
      'statement3': statement3,
      'submittedAt': now.toIso8601String(),
    });

    // Private document (only lie index)
    await _privateSubmissionsRef.doc(uid).set({
      'uid': uid,
      'lieIndex': lieIndex,
      'submittedAt': now.toIso8601String(),
    });
  }

  /// Get random submissions from other users to guess.
  Future<List<TwoTruthsSubmission>> getSubmissionsToGuess({
    required String currentUid,
    int limit = 10,
  }) async {
    // Get submissions the user hasn't guessed yet
    final guessedQuery = await _guessesRef
        .where('guesserUid', isEqualTo: currentUid)
        .get();
    
    final guessedUids = guessedQuery.docs
        .map((doc) => doc.data()['targetUid'] as String)
        .toSet();
    
    // Add current user to excluded list
    guessedUids.add(currentUid);

    // Get all public submissions
    final allSubmissions = await _publicSubmissionsRef.get();
    
    final available = allSubmissions.docs
        .where((doc) => !guessedUids.contains(doc.id))
        .map((doc) {
          final data = doc.data();
          return TwoTruthsSubmission(
            uid: data['uid'] as String,
            statement1: data['statement1'] as String,
            statement2: data['statement2'] as String,
            statement3: data['statement3'] as String,
            lieIndex: -1,
            submittedAt: DateTime.parse(data['submittedAt'] as String),
          );
        })
        .toList();
    
    // Shuffle and limit
    available.shuffle();
    return available.take(limit).toList();
  }

  /// Submit a guess and get immediate result.
  /// Returns GuessResult with correctness and the actual lie index.
  Future<GuessResult> submitGuessAndGetResult({
    required String guesserUid,
    required String targetUid,
    required int guessedLieIndex,
  }) async {
    // Get the actual lie index from private submissions
    final privateDoc = await _privateSubmissionsRef.doc(targetUid).get();
    final actualLieIndex = privateDoc.exists ? (privateDoc.data()!['lieIndex'] as int) : -1;
    final isCorrect = actualLieIndex == guessedLieIndex;

    // Get the public submission for display
    final publicDoc = await _publicSubmissionsRef.doc(targetUid).get();
    
    // Get user profile info
    final userDoc = await _usersRef.doc(targetUid).get();
    final userData = userDoc.data();

    final submission = TwoTruthsSubmission(
      uid: targetUid,
      statement1: publicDoc.data()?['statement1'] as String? ?? '',
      statement2: publicDoc.data()?['statement2'] as String? ?? '',
      statement3: publicDoc.data()?['statement3'] as String? ?? '',
      lieIndex: actualLieIndex,
      submittedAt: DateTime.tryParse(publicDoc.data()?['submittedAt'] as String? ?? '') ?? DateTime.now(),
      username: userData?['username'] as String?,
      profileImageB64: userData?['profileImageB64'] as String?,
    );

    // Save the guess (Cloud Function will also update leaderboard)
    await _guessesRef.add({
      'guesserUid': guesserUid,
      'targetUid': targetUid,
      'guessedLieIndex': guessedLieIndex,
      'guessedAt': DateTime.now().toIso8601String(),
      'isCorrect': isCorrect,
    });

    return GuessResult(
      isCorrect: isCorrect,
      actualLieIndex: actualLieIndex,
      guessedLieIndex: guessedLieIndex,
      submission: submission,
    );
  }

  /// Get user's complete stats.
  Future<TwoTruthsStats> getMyStats(String uid) async {
    final guesses = await _guessesRef
        .where('guesserUid', isEqualTo: uid)
        .get();
    
    final totalGuesses = guesses.docs.length;
    final correctGuesses = guesses.docs.where((doc) => doc.data()['isCorrect'] == true).length;

    final guessesOnMe = await _guessesRef
        .where('targetUid', isEqualTo: uid)
        .get();
    
    final timesGuessedOn = guessesOnMe.docs.length;
    final peopleFooled = guessesOnMe.docs.where((doc) => doc.data()['isCorrect'] == false).length;

    final hasSubmitted = await this.hasSubmitted(uid);
    
    return TwoTruthsStats(
      correctGuesses: correctGuesses,
      totalGuesses: totalGuesses,
      peopleFooled: peopleFooled,
      timesGuessedOn: timesGuessedOn,
      hasSubmitted: hasSubmitted,
    );
  }

  /// Stream of user's stats.
  Stream<TwoTruthsStats> statsStream(String uid) {
    return _guessesRef.snapshots().asyncMap((_) => getMyStats(uid));
  }

  /// Get leaderboard sorted by correct guesses.
  Future<List<TwoTruthsLeaderboardEntry>> getTopGuessers({int limit = 20}) async {
    final leaderboardSnap = await _leaderboardRef
        .orderBy('correctGuesses', descending: true)
        .limit(limit)
        .get();

    final entries = <TwoTruthsLeaderboardEntry>[];
    int rank = 1;
    
    for (final doc in leaderboardSnap.docs) {
      final data = doc.data();
      final uid = doc.id;
      
      // Fetch user profile
      final userDoc = await _usersRef.doc(uid).get();
      final userData = userDoc.data();
      
      entries.add(TwoTruthsLeaderboardEntry(
        uid: uid,
        username: userData?['username'] as String? ?? 'Anonymous',
        correctGuesses: data['correctGuesses'] as int? ?? 0,
        totalGuesses: data['totalGuesses'] as int? ?? 0,
        peopleFooled: data['peopleFooled'] as int? ?? 0,
        timesGuessedOn: data['timesGuessedOn'] as int? ?? 0,
        profileImageB64: userData?['profileImageB64'] as String?,
        rank: rank++,
      ));
    }
    
    return entries;
  }

  /// Get leaderboard sorted by people fooled (best liars).
  Future<List<TwoTruthsLeaderboardEntry>> getBestLiars({int limit = 20}) async {
    final leaderboardSnap = await _leaderboardRef
        .orderBy('peopleFooled', descending: true)
        .limit(limit)
        .get();

    final entries = <TwoTruthsLeaderboardEntry>[];
    int rank = 1;
    
    for (final doc in leaderboardSnap.docs) {
      final data = doc.data();
      final uid = doc.id;
      
      // Fetch user profile
      final userDoc = await _usersRef.doc(uid).get();
      final userData = userDoc.data();
      
      entries.add(TwoTruthsLeaderboardEntry(
        uid: uid,
        username: userData?['username'] as String? ?? 'Anonymous',
        correctGuesses: data['correctGuesses'] as int? ?? 0,
        totalGuesses: data['totalGuesses'] as int? ?? 0,
        peopleFooled: data['peopleFooled'] as int? ?? 0,
        timesGuessedOn: data['timesGuessedOn'] as int? ?? 0,
        profileImageB64: userData?['profileImageB64'] as String?,
        rank: rank++,
      ));
    }
    
    return entries;
  }

  /// Stream of available submissions count to guess.
  Stream<int> availableToGuessCountStream(String currentUid) {
    return _publicSubmissionsRef.snapshots().asyncMap((snapshot) async {
      final guessedQuery = await _guessesRef
          .where('guesserUid', isEqualTo: currentUid)
          .get();
      
      final guessedUids = guessedQuery.docs
          .map((doc) => doc.data()['targetUid'] as String)
          .toSet();
      
      guessedUids.add(currentUid);

      return snapshot.docs.where((doc) => !guessedUids.contains(doc.id)).length;
    });
  }
}
