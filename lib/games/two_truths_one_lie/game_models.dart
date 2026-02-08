// Models for "Two Truths & One Lie" game.

/// A user's submission containing two truths and one lie.
class TwoTruthsSubmission {
  const TwoTruthsSubmission({
    required this.uid,
    required this.statement1,
    required this.statement2,
    required this.statement3,
    required this.lieIndex,
    required this.submittedAt,
    this.username,
    this.profileImageB64,
  });

  final String uid;
  final String statement1;
  final String statement2;
  final String statement3;
  final int lieIndex; // 0, 1, or 2 - which statement is the lie (-1 if hidden)
  final DateTime submittedAt;
  final String? username;
  final String? profileImageB64;

  List<String> get statements => [statement1, statement2, statement3];

  TwoTruthsSubmission copyWith({
    String? uid,
    String? statement1,
    String? statement2,
    String? statement3,
    int? lieIndex,
    DateTime? submittedAt,
    String? username,
    String? profileImageB64,
  }) => TwoTruthsSubmission(
    uid: uid ?? this.uid,
    statement1: statement1 ?? this.statement1,
    statement2: statement2 ?? this.statement2,
    statement3: statement3 ?? this.statement3,
    lieIndex: lieIndex ?? this.lieIndex,
    submittedAt: submittedAt ?? this.submittedAt,
    username: username ?? this.username,
    profileImageB64: profileImageB64 ?? this.profileImageB64,
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'statement1': statement1,
    'statement2': statement2,
    'statement3': statement3,
    'lieIndex': lieIndex,
    'submittedAt': submittedAt.toIso8601String(),
  };

  factory TwoTruthsSubmission.fromMap(Map<String, dynamic> map) => TwoTruthsSubmission(
    uid: map['uid'] as String,
    statement1: map['statement1'] as String,
    statement2: map['statement2'] as String,
    statement3: map['statement3'] as String,
    lieIndex: map['lieIndex'] as int? ?? -1,
    submittedAt: DateTime.parse(map['submittedAt'] as String),
  );
}

/// Result of a guess - returned immediately after guessing.
class GuessResult {
  const GuessResult({
    required this.isCorrect,
    required this.actualLieIndex,
    required this.guessedLieIndex,
    required this.submission,
  });

  final bool isCorrect;
  final int actualLieIndex;
  final int guessedLieIndex;
  final TwoTruthsSubmission submission;
}

/// A guess made by another user.
class TwoTruthsGuess {
  const TwoTruthsGuess({
    required this.guesserUid,
    required this.targetUid,
    required this.guessedLieIndex,
    required this.isCorrect,
    required this.guessedAt,
  });

  final String guesserUid;
  final String targetUid;
  final int guessedLieIndex;
  final bool isCorrect;
  final DateTime guessedAt;

  Map<String, dynamic> toMap() => {
    'guesserUid': guesserUid,
    'targetUid': targetUid,
    'guessedLieIndex': guessedLieIndex,
    'isCorrect': isCorrect,
    'guessedAt': guessedAt.toIso8601String(),
  };

  factory TwoTruthsGuess.fromMap(Map<String, dynamic> map) => TwoTruthsGuess(
    guesserUid: map['guesserUid'] as String,
    targetUid: map['targetUid'] as String,
    guessedLieIndex: map['guessedLieIndex'] as int,
    isCorrect: map['isCorrect'] as bool,
    guessedAt: DateTime.parse(map['guessedAt'] as String),
  );
}

/// Leaderboard entry for correct guesses.
class TwoTruthsLeaderboardEntry {
  const TwoTruthsLeaderboardEntry({
    required this.uid,
    required this.username,
    required this.correctGuesses,
    required this.totalGuesses,
    required this.peopleFooled,
    required this.timesGuessedOn,
    this.profileImageB64,
    this.rank,
  });

  final String uid;
  final String username;
  final int correctGuesses;
  final int totalGuesses;
  final int peopleFooled; // How many people guessed wrong on this user's submission
  final int timesGuessedOn; // Total times others guessed on this user's submission
  final String? profileImageB64;
  final int? rank;

  double get accuracy => totalGuesses > 0 ? (correctGuesses / totalGuesses) * 100 : 0;
  double get foolRate => timesGuessedOn > 0 ? (peopleFooled / timesGuessedOn) * 100 : 0;

  factory TwoTruthsLeaderboardEntry.fromMap(Map<String, dynamic> map, {int? rank}) => TwoTruthsLeaderboardEntry(
    uid: map['uid'] as String? ?? '',
    username: map['username'] as String? ?? 'Anonymous',
    correctGuesses: map['correctGuesses'] as int? ?? 0,
    totalGuesses: map['totalGuesses'] as int? ?? 0,
    peopleFooled: map['peopleFooled'] as int? ?? 0,
    timesGuessedOn: map['timesGuessedOn'] as int? ?? 0,
    profileImageB64: map['profileImageB64'] as String?,
    rank: rank,
  );
}

/// User's personal stats for the game.
class TwoTruthsStats {
  const TwoTruthsStats({
    required this.correctGuesses,
    required this.totalGuesses,
    required this.peopleFooled,
    required this.timesGuessedOn,
    required this.hasSubmitted,
  });

  final int correctGuesses;
  final int totalGuesses;
  final int peopleFooled;
  final int timesGuessedOn;
  final bool hasSubmitted;

  double get accuracy => totalGuesses > 0 ? (correctGuesses / totalGuesses) * 100 : 0;
  double get foolRate => timesGuessedOn > 0 ? (peopleFooled / timesGuessedOn) * 100 : 0;

  static const empty = TwoTruthsStats(
    correctGuesses: 0,
    totalGuesses: 0,
    peopleFooled: 0,
    timesGuessedOn: 0,
    hasSubmitted: false,
  );
}
