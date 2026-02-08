/// Models for "Run For Your Type" Valentine game.

/// A single yes/no question in the game.
class GameQuestion {
  const GameQuestion({
    required this.id,
    required this.text,
    required this.category,
    this.forGender,
  });

  /// Unique identifier for this question.
  final String id;

  /// The question text to display.
  final String text;

  /// Category: 'about_me' or 'preferred_match'
  final String category;

  /// If set, this question is only shown to users of this gender.
  /// null means shown to all.
  final String? forGender;
}

/// User's answer to a question.
class GameAnswer {
  const GameAnswer({
    required this.questionId,
    required this.answer,
  });

  final String questionId;
  final bool answer; // true = Yes, false = No

  Map<String, dynamic> toMap() => {
    'questionId': questionId,
    'answer': answer,
  };

  factory GameAnswer.fromMap(Map<String, dynamic> map) => GameAnswer(
    questionId: map['questionId'] as String,
    answer: map['answer'] as bool,
  );
}

/// Complete game submission from a user.
class GameSubmission {
  const GameSubmission({
    required this.uid,
    required this.gender,
    required this.aboutMeAnswers,
    required this.preferredMatchAnswers,
    required this.submittedAt,
  });

  final String uid;
  final String gender;
  final List<GameAnswer> aboutMeAnswers;
  final List<GameAnswer> preferredMatchAnswers;
  final DateTime submittedAt;

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'gender': gender,
    'aboutMeAnswers': aboutMeAnswers.map((a) => a.toMap()).toList(),
    'preferredMatchAnswers': preferredMatchAnswers.map((a) => a.toMap()).toList(),
    'submittedAt': submittedAt.toIso8601String(),
  };

  factory GameSubmission.fromMap(Map<String, dynamic> map) => GameSubmission(
    uid: map['uid'] as String,
    gender: map['gender'] as String,
    aboutMeAnswers: (map['aboutMeAnswers'] as List)
        .map((a) => GameAnswer.fromMap(a as Map<String, dynamic>))
        .toList(),
    preferredMatchAnswers: (map['preferredMatchAnswers'] as List)
        .map((a) => GameAnswer.fromMap(a as Map<String, dynamic>))
        .toList(),
    submittedAt: DateTime.parse(map['submittedAt'] as String),
  );
}

/// Result of matching two users.
class MatchResult {
  const MatchResult({
    required this.otherUid,
    required this.otherUsername,
    required this.matchPercentage,
    this.profileImageBytes,
  });

  final String otherUid;
  final String otherUsername;
  final double matchPercentage;
  final List<int>? profileImageBytes;

  String get matchLabel {
    if (matchPercentage >= 80) return 'Strong Match 💕';
    if (matchPercentage >= 60) return 'Good Match 💗';
    if (matchPercentage >= 40) return 'Moderate Match 💓';
    return 'Low Match 💔';
  }
}
