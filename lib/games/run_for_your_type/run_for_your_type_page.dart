import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/firebase_auth_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../share_game_dialog.dart';
import 'game_controller.dart';
import 'game_models.dart';
import 'game_questions.dart';
import 'game_results_page.dart';

/// Share message for inviting friends to play.
const String _shareMessage = '''💘 Run For Your Type - Valentine's Game! 💘

Hey! Come play "Run For Your Type" with me! 🎮

Answer fun questions about yourself and what you're looking for in a match. Results are revealed on Valentine's Day!

🎯 Find your perfect match
👥 See compatibility scores
💕 Play now in the Games tab!''';

/// Main game page for "Run For Your Type" Valentine game.
/// 
/// Flow:
/// 1. Introduction screen
/// 2. "About Me" questions (describe yourself)
/// 3. "My Preferred Match" questions (what you want)
/// 4. Submit and show confirmation
class RunForYourTypePage extends StatefulWidget {
  const RunForYourTypePage({
    super.key,
    required this.uid,
    required this.gender,
    required this.auth,
    this.social,
    this.chat,
  });

  final String uid;
  final String gender;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController? social;
  final FirestoreChatController? chat;

  @override
  State<RunForYourTypePage> createState() => _RunForYourTypePageState();
}

enum _GamePhase { intro, aboutMe, preferredMatch, submitting, completed }

class _RunForYourTypePageState extends State<RunForYourTypePage> 
    with SingleTickerProviderStateMixin {
  final _controller = RunForYourTypeController();
  
  _GamePhase _phase = _GamePhase.intro;
  int _currentQuestionIndex = 0;
  
  late List<GameQuestion> _aboutMeQuestions;
  late List<GameQuestion> _preferredMatchQuestions;
  
  final List<GameAnswer> _aboutMeAnswers = [];
  final List<GameAnswer> _preferredMatchAnswers = [];
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _hasAlreadySubmitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    
    // Get questions based on gender
    _aboutMeQuestions = getAboutMeQuestions(widget.gender);
    _preferredMatchQuestions = getPreferredMatchQuestions(widget.gender);
    
    // Setup animations
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    
    _animController.forward();
    
    // Check if user already submitted
    _checkExistingSubmission();
  }

  Future<void> _checkExistingSubmission() async {
    final hasSubmitted = await _controller.hasUserSubmitted(widget.uid);
    if (hasSubmitted && mounted) {
      setState(() => _hasAlreadySubmitted = true);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _animateToNext() {
    _animController.reset();
    _animController.forward();
  }

  void _answerQuestion(bool answer) {
    HapticFeedback.lightImpact();
    
    final currentQuestions = _phase == _GamePhase.aboutMe 
        ? _aboutMeQuestions 
        : _preferredMatchQuestions;
    final currentAnswers = _phase == _GamePhase.aboutMe 
        ? _aboutMeAnswers 
        : _preferredMatchAnswers;
    
    // Record answer
    currentAnswers.add(GameAnswer(
      questionId: currentQuestions[_currentQuestionIndex].id,
      answer: answer,
    ));
    
    // Move to next question or phase
    if (_currentQuestionIndex < currentQuestions.length - 1) {
      setState(() => _currentQuestionIndex++);
      _animateToNext();
    } else {
      // Move to next phase
      if (_phase == _GamePhase.aboutMe) {
        setState(() {
          _phase = _GamePhase.preferredMatch;
          _currentQuestionIndex = 0;
        });
        // Use addPostFrameCallback to ensure setState completes before animating
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _animateToNext();
          }
        });
      } else {
        // Submit answers
        _submitAnswers();
      }
    }
  }

  Future<void> _submitAnswers() async {
    setState(() => _phase = _GamePhase.submitting);
    
    try {
      await _controller.submitAnswers(
        uid: widget.uid,
        gender: widget.gender,
        aboutMeAnswers: _aboutMeAnswers,
        preferredMatchAnswers: _preferredMatchAnswers,
      );
      
      if (mounted) {
        setState(() => _phase = _GamePhase.completed);
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to submit: $e';
          _phase = _GamePhase.preferredMatch;
        });
      }
    }
  }

  void _startGame() {
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _GamePhase.aboutMe;
      _currentQuestionIndex = 0;
    });
    _animateToNext();
  }

  void _viewResults() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameResultsPage(
          uid: widget.uid,
          gender: widget.gender,
          auth: widget.auth,
          controller: _controller,
          social: widget.social,
          chat: widget.chat,
        ),
      ),
    );
  }

  Future<void> _shareGame() async {
    if (widget.social == null || widget.chat == null) {
      // Fallback: show a snackbar if controllers not available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share feature not available')),
      );
      return;
    }

    // Get current user's email
    final currentUser = await widget.auth.publicProfileByUid(widget.uid);
    if (currentUser == null || !mounted) return;

    await ShareGameDialog.show(
      context: context,
      currentUserUid: widget.uid,
      currentUserEmail: currentUser.email,
      auth: widget.auth,
      social: widget.social!,
      chat: widget.chat!,
      gameTitle: 'Run For Your Type',
      gameEmoji: '💘',
      shareMessage: _shareMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.secondary.withValues(alpha: 0.05),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: _buildContent(theme),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    // If already submitted, show option to view results
    if (_hasAlreadySubmitted && _phase == _GamePhase.intro) {
      return _buildAlreadySubmittedView(theme);
    }

    switch (_phase) {
      case _GamePhase.intro:
        return _buildIntroScreen(theme);
      case _GamePhase.aboutMe:
      case _GamePhase.preferredMatch:
        return _buildQuestionScreen(theme);
      case _GamePhase.submitting:
        return _buildSubmittingScreen(theme);
      case _GamePhase.completed:
        return _buildCompletedScreen(theme);
    }
  }

  Widget _buildAlreadySubmittedView(ThemeData theme) {
    final countdown = _controller.getCountdownToReveal();
    final canViewResults = _controller.shouldRevealResults();
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💝', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 24),
          Text(
            'You\'ve already played!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (canViewResults) ...[
            Text(
              'Results are ready! See who your best matches are.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _viewResults,
              icon: const Icon(Icons.favorite),
              label: const Text('View My Matches'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ] else ...[
            Text(
              'Results will be revealed on\nValentine\'s Day! 💕',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _CountdownWidget(countdown: countdown, theme: theme),
          ],
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroScreen(ThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // Decorative header
              const Text('💘', style: TextStyle(fontSize: 70)),
              const SizedBox(height: 16),
              
              Text(
                'Run For Your Type',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              Text(
                'Find your perfect Valentine match!',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Instructions
              _InstructionCard(
                icon: Icons.person_outline,
                title: 'Step 1: About You',
                description: 'Answer questions about yourself',
                theme: theme,
              ),
              const SizedBox(height: 10),
              _InstructionCard(
                icon: Icons.favorite_outline,
                title: 'Step 2: Your Type',
                description: 'Tell us what you\'re looking for',
                theme: theme,
              ),
              const SizedBox(height: 10),
              _InstructionCard(
                icon: Icons.celebration_outlined,
                title: 'Step 3: Get Matched!',
                description: 'See your matches on Feb 14th',
                theme: theme,
              ),
              
              const SizedBox(height: 32),
              
              // Start button
              FilledButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Game'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Share button
              OutlinedButton.icon(
                onPressed: _shareGame,
                icon: const Icon(Icons.share),
                label: const Text('Invite Friends'),
              ),
              
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Maybe Later'),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionScreen(ThemeData theme) {
    final isAboutMe = _phase == _GamePhase.aboutMe;
    final questions = isAboutMe ? _aboutMeQuestions : _preferredMatchQuestions;
    final question = questions[_currentQuestionIndex];
    final totalQuestions = _aboutMeQuestions.length + _preferredMatchQuestions.length;
    final currentOverall = isAboutMe 
        ? _currentQuestionIndex + 1 
        : _aboutMeQuestions.length + _currentQuestionIndex + 1;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header with back button and progress
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          isAboutMe ? '👤 About Me' : '💕 My Type',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Question $currentOverall of $totalQuestions',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the close button
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: currentOverall / totalQuestions,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              
              const Spacer(),
              
              // Question card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      isAboutMe ? '🪞' : '💭',
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      question.text,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Answer buttons
              Row(
                children: [
                  Expanded(
                    child: _AnswerButton(
                      label: 'No',
                      emoji: '👎',
                      isPositive: false,
                      onTap: () => _answerQuestion(false),
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _AnswerButton(
                      label: 'Yes',
                      emoji: '👍',
                      isPositive: true,
                      onTap: () => _answerQuestion(true),
                      theme: theme,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmittingScreen(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Submitting your answers...',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '💕 Finding your matches',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedScreen(ThemeData theme) {
    final countdown = _controller.getCountdownToReveal();
    final canViewResults = _controller.shouldRevealResults();
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 24),
            
            Text(
              'You\'re In!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Your answers have been submitted successfully!',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            if (canViewResults) ...[
              Text(
                'Results are ready!',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _viewResults,
                icon: const Icon(Icons.favorite),
                label: const Text('See My Matches'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      'Results will be revealed on',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '💝 Valentine\'s Day 💝',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _CountdownWidget(countdown: countdown, theme: theme),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Share to invite more friends
              FilledButton.icon(
                onPressed: _shareGame,
                icon: const Icon(Icons.share),
                label: const Text('Invite Friends to Play'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              
              Text(
                'More players = more matches! 💕',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home),
              label: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HELPER WIDGETS
// ============================================================

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String description;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.emoji,
    required this.isPositive,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final String emoji;
  final bool isPositive;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPositive 
          ? Colors.green.shade50 
          : Colors.red.shade50,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPositive 
                  ? Colors.green.shade200 
                  : Colors.red.shade200,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownWidget extends StatelessWidget {
  const _CountdownWidget({
    required this.countdown,
    required this.theme,
  });

  final Duration countdown;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final days = countdown.inDays;
    final hours = countdown.inHours % 24;
    final minutes = countdown.inMinutes % 60;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CountdownUnit(value: days, label: 'Days', theme: theme),
        const SizedBox(width: 12),
        _CountdownUnit(value: hours, label: 'Hours', theme: theme),
        const SizedBox(width: 12),
        _CountdownUnit(value: minutes, label: 'Mins', theme: theme),
      ],
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  const _CountdownUnit({
    required this.value,
    required this.label,
    required this.theme,
  });

  final int value;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
