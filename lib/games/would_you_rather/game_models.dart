class WouldYouRatherQuestion {
  const WouldYouRatherQuestion({
    required this.id,
    required this.optionA,
    required this.optionB,
    this.category,
  });

  final String id;
  final String optionA;
  final String optionB;
  final String? category;

  Map<String, dynamic> toMap() => {
    'id': id,
    'optionA': optionA,
    'optionB': optionB,
    if (category != null) 'category': category,
  };

  factory WouldYouRatherQuestion.fromMap(Map<String, dynamic> map) =>
      WouldYouRatherQuestion(
        id: map['id'] as String,
        optionA: map['optionA'] as String,
        optionB: map['optionB'] as String,
        category: map['category'] as String?,
      );
}

/// Status of a game session
enum SessionStatus { waiting, playing, finished, cancelled }

/// A two-player game session
class WouldYouRatherSession {
  const WouldYouRatherSession({
    required this.id,
    required this.player1Uid,
    this.player2Uid,
    required this.status,
    required this.questionIds,
    required this.currentQuestionIndex,
    this.questionStartedAt,
    required this.createdAt,
    this.player1Name,
    this.player2Name,
    this.player1ImageB64,
    this.player2ImageB64,
    this.matches = 0,
    this.totalAnswered = 0,
  });

  final String id;
  final String player1Uid;
  final String? player2Uid;
  final SessionStatus status;
  final List<String> questionIds;
  final int currentQuestionIndex;
  final DateTime? questionStartedAt;
  final DateTime createdAt;
  final String? player1Name;
  final String? player2Name;
  final String? player1ImageB64;
  final String? player2ImageB64;
  final int matches;
  final int totalAnswered;

  bool get isWaitingForPlayer => status == SessionStatus.waiting;
  bool get isPlaying => status == SessionStatus.playing;
  bool get isFinished => status == SessionStatus.finished;
  bool get isFull => player2Uid != null;
  int get totalQuestions => questionIds.length;
  double get compatibilityPercent => 
      totalAnswered > 0 ? (matches / totalAnswered) * 100 : 0;

  String getOpponentUid(String myUid) =>
      myUid == player1Uid ? (player2Uid ?? '') : player1Uid;

  String? getOpponentName(String myUid) =>
      myUid == player1Uid ? player2Name : player1Name;

  String? getOpponentImage(String myUid) =>
      myUid == player1Uid ? player2ImageB64 : player1ImageB64;

  String? getMyName(String myUid) =>
      myUid == player1Uid ? player1Name : player2Name;

  String? getMyImage(String myUid) =>
      myUid == player1Uid ? player1ImageB64 : player2ImageB64;

  WouldYouRatherSession copyWith({
    String? id,
    String? player1Uid,
    String? player2Uid,
    SessionStatus? status,
    List<String>? questionIds,
    int? currentQuestionIndex,
    DateTime? questionStartedAt,
    DateTime? createdAt,
    String? player1Name,
    String? player2Name,
    String? player1ImageB64,
    String? player2ImageB64,
    int? matches,
    int? totalAnswered,
  }) =>
      WouldYouRatherSession(
        id: id ?? this.id,
        player1Uid: player1Uid ?? this.player1Uid,
        player2Uid: player2Uid ?? this.player2Uid,
        status: status ?? this.status,
        questionIds: questionIds ?? this.questionIds,
        currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
        questionStartedAt: questionStartedAt ?? this.questionStartedAt,
        createdAt: createdAt ?? this.createdAt,
        player1Name: player1Name ?? this.player1Name,
        player2Name: player2Name ?? this.player2Name,
        player1ImageB64: player1ImageB64 ?? this.player1ImageB64,
        player2ImageB64: player2ImageB64 ?? this.player2ImageB64,
        matches: matches ?? this.matches,
        totalAnswered: totalAnswered ?? this.totalAnswered,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'player1Uid': player1Uid,
    'player2Uid': player2Uid,
    'status': status.name,
    'questionIds': questionIds,
    'currentQuestionIndex': currentQuestionIndex,
    'questionStartedAt': questionStartedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'player1Name': player1Name,
    'player2Name': player2Name,
    'player1ImageB64': player1ImageB64,
    'player2ImageB64': player2ImageB64,
    'matches': matches,
    'totalAnswered': totalAnswered,
  };

  factory WouldYouRatherSession.fromMap(Map<String, dynamic> map, String docId) =>
      WouldYouRatherSession(
        id: docId,
        player1Uid: map['player1Uid'] as String,
        player2Uid: map['player2Uid'] as String?,
        status: SessionStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => SessionStatus.waiting,
        ),
        questionIds: List<String>.from(map['questionIds'] ?? []),
        currentQuestionIndex: map['currentQuestionIndex'] as int? ?? 0,
        questionStartedAt: map['questionStartedAt'] != null
            ? DateTime.parse(map['questionStartedAt'] as String)
            : null,
        createdAt: DateTime.parse(map['createdAt'] as String),
        player1Name: map['player1Name'] as String?,
        player2Name: map['player2Name'] as String?,
        player1ImageB64: map['player1ImageB64'] as String?,
        player2ImageB64: map['player2ImageB64'] as String?,
        matches: map['matches'] as int? ?? 0,
        totalAnswered: map['totalAnswered'] as int? ?? 0,
      );
}

/// A player's answer to a question in a session
class WouldYouRatherAnswer {
  const WouldYouRatherAnswer({
    required this.sessionId,
    required this.playerUid,
    required this.questionId,
    required this.choice,
    required this.answeredAt,
  });

  final String sessionId;
  final String playerUid;
  final String questionId;
  final String choice; // 'A' or 'B'
  final DateTime answeredAt;

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId,
    'playerUid': playerUid,
    'questionId': questionId,
    'choice': choice,
    'answeredAt': answeredAt.toIso8601String(),
  };

  factory WouldYouRatherAnswer.fromMap(Map<String, dynamic> map) =>
      WouldYouRatherAnswer(
        sessionId: map['sessionId'] as String,
        playerUid: map['playerUid'] as String,
        questionId: map['questionId'] as String,
        choice: map['choice'] as String,
        answeredAt: DateTime.parse(map['answeredAt'] as String),
      );
}

/// Result for a single question showing both players' answers
class QuestionResult {
  const QuestionResult({
    required this.question,
    required this.player1Choice,
    required this.player2Choice,
  });

  final WouldYouRatherQuestion question;
  final String? player1Choice; // null if timed out
  final String? player2Choice; // null if timed out

  bool get bothAnswered => player1Choice != null && player2Choice != null;
  bool get isMatch => bothAnswered && player1Choice == player2Choice;
  bool get isSkipped => player1Choice == null || player2Choice == null;
}

/// Final game result with all question results
class WouldYouRatherResult {
  const WouldYouRatherResult({
    required this.session,
    required this.questionResults,
  });

  final WouldYouRatherSession session;
  final List<QuestionResult> questionResults;

  int get matches => questionResults.where((r) => r.isMatch).length;
  int get total => questionResults.length;
  int get skipped => questionResults.where((r) => r.isSkipped).length;
  double get compatibilityPercent => total > 0 ? (matches / total) * 100 : 0;
}
