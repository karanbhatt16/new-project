import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import 'game_controller.dart';
import 'game_models.dart';
import 'questions.dart';

/// Game states
enum GameState { lobby, waiting, playing, revealing, results }

class WouldYouRatherPage extends StatefulWidget {
  const WouldYouRatherPage({
    super.key,
    required this.uid,
    required this.email,
    required this.auth,
    required this.social,
    required this.chat,
  });

  final String uid;
  final String email;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;
  final FirestoreChatController chat;

  @override
  State<WouldYouRatherPage> createState() => _WouldYouRatherPageState();
}

class _WouldYouRatherPageState extends State<WouldYouRatherPage> {
  final _controller = WouldYouRatherController();
  
  GameState _gameState = GameState.lobby;
  WouldYouRatherSession? _session;
  WouldYouRatherResult? _result;
  StreamSubscription<WouldYouRatherSession?>? _sessionSub;
  StreamSubscription<Map<String, String>>? _answersSub;
  
  // Timer
  Timer? _timer;
  int _secondsLeft = 10;
  static const int _questionDuration = 10;
  
  // Current question state
  String? _myChoice;
  String? _opponentChoice;
  bool _hasAnswered = false;
  bool _isRevealing = false;

  String _myName = 'You';
  String? _myImage;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    final profile = await widget.auth.getCurrentProfile();
    if (mounted && profile != null) {
      setState(() {
        _myName = profile.username.isNotEmpty ? profile.username : 'You';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sessionSub?.cancel();
    _answersSub?.cancel();
    super.dispose();
  }

  // ============ LOBBY ACTIONS ============

  Future<void> _findRandomMatch() async {
    setState(() => _gameState = GameState.waiting);
    
    try {
      final session = await _controller.findRandomMatch(
        uid: widget.uid,
        name: _myName,
        imageB64: _myImage,
      );
      
      if (session != null) {
        _subscribeToSession(session.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _gameState = GameState.lobby);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finding match: $e')),
        );
      }
    }
  }

  Future<void> _createInviteSession() async {
    setState(() => _gameState = GameState.waiting);
    
    try {
      final session = await _controller.createSession(
        hostUid: widget.uid,
        hostName: _myName,
        hostImageB64: _myImage,
      );
      
      _subscribeToSession(session.id);
      
      if (mounted) {
        _showInviteDialog(session.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _gameState = GameState.lobby);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating session: $e')),
        );
      }
    }
  }

  void _showInviteDialog(String sessionId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InviteFriendSheet(
        sessionId: sessionId,
        currentUserUid: widget.uid,
        currentUserEmail: widget.email,
        auth: widget.auth,
        social: widget.social,
        chat: widget.chat,
      ),
    );
  }

  Future<void> _joinWithCode() async {
    final codeController = TextEditingController();
    
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Game'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Enter invite code',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, codeController.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (code == null || code.isEmpty) return;

    setState(() => _gameState = GameState.waiting);

    try {
      final session = await _controller.joinViaInvite(
        inviteCode: code,
        joinerUid: widget.uid,
        joinerName: _myName,
        joinerImageB64: _myImage,
      );

      if (session != null) {
        _subscribeToSession(session.id);
      } else {
        if (mounted) {
          setState(() => _gameState = GameState.lobby);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not join game. Invalid or expired code.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _gameState = GameState.lobby);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining: $e')),
        );
      }
    }
  }

  Future<void> _cancelWaiting() async {
    _sessionSub?.cancel();
    _answersSub?.cancel();
    _timer?.cancel();
    
    if (_session != null) {
      await _controller.cancelMatchmaking(widget.uid);
    }
    
    if (mounted) {
      setState(() {
        _gameState = GameState.lobby;
        _session = null;
      });
    }
  }

  // ============ SESSION SUBSCRIPTION ============

  void _subscribeToSession(String sessionId) {
    _sessionSub?.cancel();
    _sessionSub = _controller.streamSession(sessionId).listen(_onSessionUpdate);
  }

  void _onSessionUpdate(WouldYouRatherSession? session) {
    if (!mounted || session == null) return;

    final previousSession = _session;
    setState(() => _session = session);

    if (session.status == SessionStatus.cancelled) {
      _showCancelledDialog();
      return;
    }

    if (session.status == SessionStatus.finished) {
      _loadResults();
      return;
    }

    if (session.status == SessionStatus.playing) {
      // Check if we just started or moved to next question
      final questionChanged = previousSession == null ||
          previousSession.currentQuestionIndex != session.currentQuestionIndex ||
          previousSession.status != SessionStatus.playing;

      if (questionChanged) {
        _startQuestion();
      }
    }
  }

  void _showCancelledDialog() {
    _timer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Cancelled'),
        content: const Text('The other player left the game.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _gameState = GameState.lobby;
                _session = null;
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ============ GAMEPLAY ============

  void _startQuestion() {
    final session = _session;
    if (session == null) return;

    setState(() {
      _gameState = GameState.playing;
      _myChoice = null;
      _opponentChoice = null;
      _hasAnswered = false;
      _isRevealing = false;
      _secondsLeft = _questionDuration;
    });

    // Subscribe to answers for current question
    final questionId = session.questionIds[session.currentQuestionIndex];
    _answersSub?.cancel();
    _answersSub = _controller.streamAnswersForQuestion(
      sessionId: session.id,
      questionId: questionId,
    ).listen(_onAnswersUpdate);

    // Start timer
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() => _secondsLeft--);

      if (_secondsLeft <= 0) {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  void _onAnswersUpdate(Map<String, String> answers) {
    if (!mounted) return;
    final session = _session;
    if (session == null) return;

    final myChoice = answers[widget.uid];
    final opponentUid = session.getOpponentUid(widget.uid);
    final opponentChoice = answers[opponentUid];

    setState(() {
      _myChoice = myChoice;
      _opponentChoice = opponentChoice;
      _hasAnswered = myChoice != null;
    });

    // Both answered - show reveal and advance
    if (myChoice != null && opponentChoice != null && !_isRevealing) {
      _showRevealAndAdvance();
    }
  }

  Future<void> _selectOption(String choice) async {
    if (_hasAnswered || _isRevealing) return;
    
    final session = _session;
    if (session == null) return;

    HapticFeedback.mediumImpact();
    
    final questionId = session.questionIds[session.currentQuestionIndex];
    
    setState(() {
      _myChoice = choice;
      _hasAnswered = true;
    });

    await _controller.submitAnswer(
      sessionId: session.id,
      playerUid: widget.uid,
      questionId: questionId,
      choice: choice,
    );
  }

  void _handleTimeout() {
    if (_isRevealing) return;
    _showRevealAndAdvance();
  }

  Future<void> _showRevealAndAdvance() async {
    _timer?.cancel();
    _answersSub?.cancel();

    final session = _session;
    if (session == null) return;

    setState(() {
      _isRevealing = true;
      _gameState = GameState.revealing;
    });

    // Show result for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Only player1 advances the game to avoid race conditions
    if (widget.uid == session.player1Uid) {
      final questionId = session.questionIds[session.currentQuestionIndex];
      
      if (_myChoice != null && _opponentChoice != null) {
        await _controller.advanceToNextQuestion(
          sessionId: session.id,
          currentIndex: session.currentQuestionIndex,
          totalQuestions: session.totalQuestions,
          questionId: questionId,
          player1Uid: session.player1Uid,
          player2Uid: session.player2Uid!,
        );
      } else {
        await _controller.skipQuestion(
          sessionId: session.id,
          currentIndex: session.currentQuestionIndex,
          totalQuestions: session.totalQuestions,
        );
      }
    }
  }

  Future<void> _loadResults() async {
    final session = _session;
    if (session == null) return;

    try {
      final result = await _controller.getGameResult(session: session);
      if (mounted) {
        setState(() {
          _result = result;
          _gameState = GameState.results;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading results: $e')),
        );
      }
    }
  }

  Future<void> _playAgain() async {
    setState(() {
      _gameState = GameState.lobby;
      _session = null;
      _result = null;
      _myChoice = null;
      _opponentChoice = null;
    });
  }

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Would You Rather'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_gameState == GameState.playing || _gameState == GameState.waiting) {
              _showExitConfirmation();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: switch (_gameState) {
        GameState.lobby => _buildLobby(),
        GameState.waiting => _buildWaiting(),
        GameState.playing || GameState.revealing => _buildPlaying(),
        GameState.results => _buildResults(),
      },
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Game?'),
        content: const Text('Are you sure you want to leave? The game will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelWaiting();
              Navigator.pop(context);
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Widget _buildLobby() {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🤔', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Would You Rather',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Play with a friend and see how compatible you are!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 48),
            
            // Random match button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _findRandomMatch,
                icon: const Icon(Icons.shuffle),
                label: const Text('Find Random Match'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Invite friend button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _createInviteSession,
                icon: const Icon(Icons.person_add),
                label: const Text('Invite a Friend'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Join with code
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _joinWithCode,
                icon: const Icon(Icons.qr_code),
                label: const Text('Join with Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiting() {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 32),
            Text(
              'Waiting for opponent...',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'This won\'t take long!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 48),
            OutlinedButton(
              onPressed: _cancelWaiting,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaying() {
    final theme = Theme.of(context);
    final session = _session;
    
    if (session == null) return const SizedBox();
    
    final questionIndex = session.currentQuestionIndex;
    if (questionIndex >= session.questionIds.length) return const SizedBox();
    
    final questionId = session.questionIds[questionIndex];
    final question = getQuestionById(questionId);
    
    if (question == null) return const SizedBox();
    
    final opponentName = session.getOpponentName(widget.uid) ?? 'Opponent';
    final isMatch = _myChoice != null && 
                    _opponentChoice != null && 
                    _myChoice == _opponentChoice;
    
    return Column(
      children: [
        // Timer bar
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 0.0),
          duration: Duration(seconds: _questionDuration),
          builder: (context, value, child) {
            return LinearProgressIndicator(
              value: _secondsLeft / _questionDuration,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: _secondsLeft <= 3 ? Colors.red : theme.colorScheme.primary,
              minHeight: 6,
            );
          },
        ),
        
        // Player avatars and status
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PlayerStatus(
                name: 'You',
                hasAnswered: _hasAnswered,
                choice: _isRevealing ? _myChoice : null,
              ),
              Column(
                children: [
                  Text(
                    '${questionIndex + 1}/${session.totalQuestions}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_secondsLeft}s',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _secondsLeft <= 3 ? Colors.red : null,
                    ),
                  ),
                ],
              ),
              _PlayerStatus(
                name: opponentName,
                hasAnswered: _opponentChoice != null,
                choice: _isRevealing ? _opponentChoice : null,
              ),
            ],
          ),
        ),
        
        // Reveal result
        if (_isRevealing) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMatch 
                  ? Colors.green.withValues(alpha: 0.2) 
                  : Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isMatch ? Icons.favorite : Icons.compare_arrows,
                  color: isMatch ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  isMatch ? 'You both chose the same!' : 'Different choices!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isMatch ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Question
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Would you rather...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                
                _OptionCard(
                  label: question.optionA,
                  selected: _myChoice == 'A',
                  revealed: _isRevealing,
                  opponentSelected: _opponentChoice == 'A',
                  onTap: () => _selectOption('A'),
                  disabled: _hasAnswered || _isRevealing,
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('OR', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                
                _OptionCard(
                  label: question.optionB,
                  selected: _myChoice == 'B',
                  revealed: _isRevealing,
                  opponentSelected: _opponentChoice == 'B',
                  onTap: () => _selectOption('B'),
                  disabled: _hasAnswered || _isRevealing,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final theme = Theme.of(context);
    final result = _result;
    final session = _session;
    
    if (result == null || session == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final opponentName = session.getOpponentName(widget.uid) ?? 'Opponent';
    final compatibility = result.compatibilityPercent;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          
          // Compatibility score
          Text(
            _getCompatibilityEmoji(compatibility),
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            '${compatibility.toStringAsFixed(0)}%',
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: _getCompatibilityColor(compatibility),
            ),
          ),
          Text(
            'Compatible with $opponentName',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.matches}/${result.total} answers matched',
            style: theme.textTheme.bodyLarge,
          ),
          if (result.skipped > 0)
            Text(
              '${result.skipped} questions skipped',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          
          const SizedBox(height: 32),
          
          // Breakdown
          Text(
            'Question Breakdown',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          ...result.questionResults.asMap().entries.map((entry) {
            final index = entry.key;
            final qResult = entry.value;
            return _QuestionResultCard(
              index: index + 1,
              result: qResult,
              myUid: widget.uid,
              session: session,
            );
          }),
          
          const SizedBox(height: 32),
          
          // Play again
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _playAgain,
              icon: const Icon(Icons.replay),
              label: const Text('Play Again'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Exit'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getCompatibilityEmoji(double percent) {
    if (percent >= 80) return '💕';
    if (percent >= 60) return '😊';
    if (percent >= 40) return '🤝';
    if (percent >= 20) return '🤔';
    return '😅';
  }

  Color _getCompatibilityColor(double percent) {
    if (percent >= 80) return Colors.pink;
    if (percent >= 60) return Colors.green;
    if (percent >= 40) return Colors.blue;
    if (percent >= 20) return Colors.orange;
    return Colors.grey;
  }
}

// ============ WIDGETS ============

class _PlayerStatus extends StatelessWidget {
  const _PlayerStatus({
    required this.name,
    required this.hasAnswered,
    this.choice,
  });

  final String name;
  final bool hasAnswered;
  final String? choice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasAnswered 
                ? Colors.green.withValues(alpha: 0.2) 
                : theme.colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: hasAnswered ? Colors.green : theme.colorScheme.outline,
              width: 2,
            ),
          ),
          child: Center(
            child: hasAnswered
                ? (choice != null 
                    ? Text(choice!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
                    : const Icon(Icons.check, color: Colors.green))
                : const Icon(Icons.hourglass_empty, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: theme.textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.revealed = false,
    this.opponentSelected = false,
    this.disabled = false,
  });

  final String label;
  final bool selected;
  final bool revealed;
  final bool opponentSelected;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color? backgroundColor;
    Color borderColor = theme.colorScheme.outlineVariant;
    
    if (revealed) {
      if (selected && opponentSelected) {
        backgroundColor = Colors.green.withValues(alpha: 0.2);
        borderColor = Colors.green;
      } else if (selected) {
        backgroundColor = theme.colorScheme.primaryContainer;
        borderColor = theme.colorScheme.primary;
      } else if (opponentSelected) {
        backgroundColor = Colors.orange.withValues(alpha: 0.2);
        borderColor = Colors.orange;
      }
    } else if (selected) {
      backgroundColor = theme.colorScheme.primaryContainer;
      borderColor = theme.colorScheme.primary;
    }
    
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: backgroundColor ?? theme.colorScheme.surface,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            if (revealed) ...[
              if (selected)
                const Icon(Icons.person, color: Colors.blue, size: 20),
              if (selected && opponentSelected)
                const SizedBox(width: 4),
              if (opponentSelected)
                const Icon(Icons.person_outline, color: Colors.orange, size: 20),
              if (selected || opponentSelected)
                const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: selected ? FontWeight.bold : null,
                ),
              ),
            ),
            if (selected && !revealed)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _QuestionResultCard extends StatelessWidget {
  const _QuestionResultCard({
    required this.index,
    required this.result,
    required this.myUid,
    required this.session,
  });

  final int index;
  final QuestionResult result;
  final String myUid;
  final WouldYouRatherSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final myChoice = myUid == session.player1Uid 
        ? result.player1Choice 
        : result.player2Choice;
    final opponentChoice = myUid == session.player1Uid 
        ? result.player2Choice 
        : result.player1Choice;
    
    final myAnswer = myChoice == 'A' ? result.question.optionA : 
                     myChoice == 'B' ? result.question.optionB : 'Skipped';
    final opponentAnswer = opponentChoice == 'A' ? result.question.optionA : 
                           opponentChoice == 'B' ? result.question.optionB : 'Skipped';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: result.isMatch 
                        ? Colors.green 
                        : result.isSkipped 
                            ? Colors.grey 
                            : Colors.orange,
                  ),
                  child: Center(
                    child: result.isMatch
                        ? const Icon(Icons.favorite, color: Colors.white, size: 16)
                        : Text(
                            '$index',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Q$index: ${result.question.optionA} vs ${result.question.optionB}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AnswerChip(
                    label: 'You',
                    answer: myAnswer,
                    isMatch: result.isMatch,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AnswerChip(
                    label: session.getOpponentName(myUid) ?? 'Opponent',
                    answer: opponentAnswer,
                    isMatch: result.isMatch,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({
    required this.label,
    required this.answer,
    required this.isMatch,
  });

  final String label;
  final String answer;
  final bool isMatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ============ INVITE FRIEND SHEET ============

class _InviteFriendSheet extends StatefulWidget {
  const _InviteFriendSheet({
    required this.sessionId,
    required this.currentUserUid,
    required this.currentUserEmail,
    required this.auth,
    required this.social,
    required this.chat,
  });

  final String sessionId;
  final String currentUserUid;
  final String currentUserEmail;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;
  final FirestoreChatController chat;

  @override
  State<_InviteFriendSheet> createState() => _InviteFriendSheetState();
}

class _InviteFriendSheetState extends State<_InviteFriendSheet> {
  List<AppUser>? _friends;
  bool _loading = true;
  String? _error;
  String? _sendingToUid;
  final Set<String> _sentToUids = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final friendUids = await widget.social.getFriends(uid: widget.currentUserUid);
      final friends = <AppUser>[];
      
      for (final uid in friendUids) {
        final user = await widget.auth.publicProfileByUid(uid);
        if (user != null) {
          friends.add(user);
        }
      }
      
      // Sort alphabetically
      friends.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
      
      if (mounted) {
        setState(() {
          _friends = friends;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendInvite(AppUser friend) async {
    if (_sendingToUid != null) return;
    
    setState(() => _sendingToUid = friend.uid);
    HapticFeedback.mediumImpact();
    
    try {
      // Get or create thread with this friend
      final thread = await widget.chat.getOrCreateThread(
        myUid: widget.currentUserUid,
        myEmail: widget.currentUserEmail,
        otherUid: friend.uid,
        otherEmail: friend.email,
      );
      
      // Send the invite message
      final inviteMessage = '🎮 Join me in Would You Rather!\n\nUse this code to play: ${widget.sessionId}';
      
      await widget.chat.sendMessagePlaintext(
        threadId: thread.id,
        fromUid: widget.currentUserUid,
        fromEmail: widget.currentUserEmail,
        toUid: friend.uid,
        toEmail: friend.email,
        text: inviteMessage,
      );
      
      if (mounted) {
        setState(() {
          _sendingToUid = null;
          _sentToUids.add(friend.uid);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite sent to ${friend.username}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingToUid = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.sessionId));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('🎮', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite a Friend',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Select a friend to send the invite',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Invite code section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.vpn_key,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite Code',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        widget.sessionId,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Divider with label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or send to a friend',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Friends list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Error loading friends: $_error',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _friends == null || _friends!.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No friends yet',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Share the code above with someone!',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _friends!.length,
                            itemBuilder: (context, index) {
                              final friend = _friends![index];
                              final isSending = _sendingToUid == friend.uid;
                              final isSent = _sentToUids.contains(friend.uid);
                              
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  backgroundImage: friend.profileImageBytes != null
                                      ? MemoryImage(Uint8List.fromList(friend.profileImageBytes!))
                                      : null,
                                  child: friend.profileImageBytes == null
                                      ? Text(
                                          friend.username.isNotEmpty 
                                              ? friend.username[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: theme.colorScheme.onPrimaryContainer,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  friend.username,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: isSent
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Sent',
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : FilledButton.tonal(
                                        onPressed: isSending ? null : () => _sendInvite(friend),
                                        child: isSending
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Text('Invite'),
                                      ),
                              );
                            },
                          ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
