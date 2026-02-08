import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/app_user.dart';
import 'game_models.dart';
import 'game_questions.dart';

/// Controller for "Run For Your Type" game data in Firestore.
class RunForYourTypeController {
  RunForYourTypeController({FirebaseFirestore? db}) 
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Collection reference for game submissions.
  CollectionReference<Map<String, dynamic>> get _submissions =>
      _db.collection('valentine_game_submissions');

  /// Check if user has already submitted their answers.
  Future<bool> hasUserSubmitted(String uid) async {
    final doc = await _submissions.doc(uid).get();
    return doc.exists;
  }

  /// Get user's existing submission if any.
  Future<GameSubmission?> getUserSubmission(String uid) async {
    final doc = await _submissions.doc(uid).get();
    if (!doc.exists) return null;
    return GameSubmission.fromMap(doc.data()!);
  }

  /// Submit user's game answers.
  Future<void> submitAnswers({
    required String uid,
    required String gender,
    required List<GameAnswer> aboutMeAnswers,
    required List<GameAnswer> preferredMatchAnswers,
  }) async {
    final submission = GameSubmission(
      uid: uid,
      gender: gender,
      aboutMeAnswers: aboutMeAnswers,
      preferredMatchAnswers: preferredMatchAnswers,
      submittedAt: DateTime.now(),
    );

    await _submissions.doc(uid).set(submission.toMap());
  }

  /// Calculate compatibility between two users.
  /// 
  /// Compares:
  /// 1. User A's preferences with User B's "about me"
  /// 2. User B's preferences with User A's "about me"
  /// 
  /// Returns average match percentage.
  double calculateCompatibility(GameSubmission userA, GameSubmission userB) {
    // Get the question mappings
    final mappingAtoB = getQuestionMapping(userA.gender);
    final mappingBtoA = getQuestionMapping(userB.gender);

    // Convert answers to maps for easy lookup
    final aboutMeA = {for (var a in userA.aboutMeAnswers) a.questionId: a.answer};
    final aboutMeB = {for (var a in userB.aboutMeAnswers) a.questionId: a.answer};
    final prefA = {for (var a in userA.preferredMatchAnswers) a.questionId: a.answer};
    final prefB = {for (var a in userB.preferredMatchAnswers) a.questionId: a.answer};

    // Calculate how well B matches A's preferences
    int matchesAtoB = 0;
    int totalAtoB = 0;
    for (final entry in mappingAtoB.entries) {
      final prefQuestionId = entry.key;
      final aboutMeQuestionId = entry.value;
      
      if (prefA.containsKey(prefQuestionId) && aboutMeB.containsKey(aboutMeQuestionId)) {
        totalAtoB++;
        // Match if: A wants X and B is X, OR A doesn't want X and B isn't X
        if (prefA[prefQuestionId] == aboutMeB[aboutMeQuestionId]) {
          matchesAtoB++;
        }
      }
    }

    // Calculate how well A matches B's preferences
    int matchesBtoA = 0;
    int totalBtoA = 0;
    for (final entry in mappingBtoA.entries) {
      final prefQuestionId = entry.key;
      final aboutMeQuestionId = entry.value;
      
      if (prefB.containsKey(prefQuestionId) && aboutMeA.containsKey(aboutMeQuestionId)) {
        totalBtoA++;
        if (prefB[prefQuestionId] == aboutMeA[aboutMeQuestionId]) {
          matchesBtoA++;
        }
      }
    }

    // Calculate percentages
    final percentAtoB = totalAtoB > 0 ? (matchesAtoB / totalAtoB) * 100 : 0.0;
    final percentBtoA = totalBtoA > 0 ? (matchesBtoA / totalBtoA) * 100 : 0.0;

    // Return average of both directions
    return (percentAtoB + percentBtoA) / 2;
  }

  /// Get all matches for a user, sorted by compatibility percentage.
  /// 
  /// This fetches all submissions from the opposite gender and calculates
  /// compatibility with each one.
  Future<List<MatchResult>> getMatchResults({
    required String uid,
    required String gender,
    required Future<AppUser?> Function(String uid) getUserProfile,
  }) async {
    // Get user's submission
    final mySubmission = await getUserSubmission(uid);
    if (mySubmission == null) return [];

    // Get all submissions from opposite gender
    final oppositeGender = gender.toLowerCase() == 'male' ? 'female' : 'male';
    final querySnapshot = await _submissions
        .where('gender', isEqualTo: oppositeGender)
        .get();

    final results = <MatchResult>[];

    for (final doc in querySnapshot.docs) {
      final otherSubmission = GameSubmission.fromMap(doc.data());
      
      // Calculate compatibility
      final matchPercentage = calculateCompatibility(mySubmission, otherSubmission);

      // Get user profile for display
      final profile = await getUserProfile(otherSubmission.uid);
      if (profile != null) {
        results.add(MatchResult(
          otherUid: otherSubmission.uid,
          otherUsername: profile.username,
          matchPercentage: matchPercentage,
          profileImageBytes: profile.profileImageBytes,
        ));
      }
    }

    // Sort by match percentage (highest first)
    results.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));

    return results;
  }

  /// Stream of submission count (for showing participation stats).
  Stream<int> submissionCountStream() {
    return _submissions.snapshots().map((snap) => snap.docs.length);
  }

  /// Check if results should be revealed (Feb 14, 2026 or later).
  bool shouldRevealResults() {
    final revealDate = DateTime(2026, 2, 14);
    return DateTime.now().isAfter(revealDate) || DateTime.now().isAtSameMomentAs(revealDate);
  }

  /// Get countdown to reveal date.
  Duration getCountdownToReveal() {
    final revealDate = DateTime(2026, 2, 14);
    final now = DateTime.now();
    if (now.isAfter(revealDate)) return Duration.zero;
    return revealDate.difference(now);
  }
}
