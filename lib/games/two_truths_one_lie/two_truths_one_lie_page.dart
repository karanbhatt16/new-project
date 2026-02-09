import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/firebase_auth_controller.dart';
import '../../ui/widgets/skeleton_widgets.dart';
import 'game_controller.dart';
import 'game_models.dart';

class TwoTruthsOneLiePage extends StatefulWidget {
  const TwoTruthsOneLiePage({
    super.key,
    required this.uid,
    required this.auth,
  });

  final String uid;
  final FirebaseAuthController auth;

  @override
  State<TwoTruthsOneLiePage> createState() => _TwoTruthsOneLiePageState();
}

class _TwoTruthsOneLiePageState extends State<TwoTruthsOneLiePage> with SingleTickerProviderStateMixin {
  final _controller = TwoTruthsController();
  final _s1 = TextEditingController();
  final _s2 = TextEditingController();
  final _s3 = TextEditingController();
  
  late TabController _tabController;
  int _lieIndex = 0;
  bool _loading = true;
  bool _submitting = false;
  List<TwoTruthsSubmission> _queue = [];
  TwoTruthsStats _stats = TwoTruthsStats.empty;
  
  // Leaderboard data
  List<TwoTruthsLeaderboardEntry> _topGuessers = [];
  List<TwoTruthsLeaderboardEntry> _bestLiars = [];
  bool _loadingLeaderboard = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _load();
  }

  void _onTabChanged() {
    if (_tabController.index == 2 && _topGuessers.isEmpty) {
      _loadLeaderboard();
    }
  }

  Future<void> _load() async {
    debugPrint('📱 ========== STARTING LOAD ==========');
    debugPrint('📱 Current user UID: ${widget.uid}');
    
    try {
      debugPrint('📱 Step 1: Getting user submission...');
      final sub = await _controller.getSubmission(widget.uid);
      debugPrint('📱 Step 1 complete. Has submission: ${sub != null}');
      
      debugPrint('📱 Step 2: Getting lie index...');
      final myLieIndex = await _controller.getMyLieIndex(widget.uid);
      debugPrint('📱 Step 2 complete. Lie index: $myLieIndex');
      
      debugPrint('📱 Step 3: Getting submissions to guess...');
      final toGuess = await _controller.getSubmissionsToGuess(currentUid: widget.uid, limit: 10);
      debugPrint('📱 Step 3 complete. Found ${toGuess.length} submissions');
      debugPrint('📱 Queue contents: ${toGuess.map((s) => 'uid:${s.uid}, stmt1:${s.statement1.substring(0, 20)}...').toList()}');
      
      debugPrint('📱 Step 4: Getting stats...');
      final stats = await _controller.getMyStats(widget.uid);
      debugPrint('📱 Step 4 complete. Stats: correct=${stats.correctGuesses}, total=${stats.totalGuesses}');
      
      if (mounted) {
        debugPrint('📱 Step 5: Updating UI state...');
        setState(() {
          _loading = false;
          if (sub != null) {
            _s1.text = sub.statement1;
            _s2.text = sub.statement2;
            _s3.text = sub.statement3;
          }
          _lieIndex = myLieIndex ?? 0;
          _queue = toGuess;
          _stats = stats;
        });
        debugPrint('📱 Step 5 complete. UI state: _queue.length = ${_queue.length}, _loading = $_loading');
        debugPrint('📱 ========== LOAD COMPLETE ==========');
      } else {
        debugPrint('📱 WARNING: Widget not mounted, skipping state update');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR loading Two Truths game: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _loading = false;
          // Keep defaults, just stop loading
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading game data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadLeaderboard() async {
    if (_loadingLeaderboard) return;
    setState(() => _loadingLeaderboard = true);
    
    try {
      final guessers = await _controller.getTopGuessers(limit: 20);
      final liars = await _controller.getBestLiars(limit: 20);
      
      if (mounted) {
        setState(() {
          _topGuessers = guessers;
          _bestLiars = liars;
          _loadingLeaderboard = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingLeaderboard = false);
    }
  }

  Future<void> _resetGuesses() async {
    try {
      debugPrint('🔄 Resetting all guesses for user: ${widget.uid}');
      await _controller.resetMyGuesses(widget.uid);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your guesses have been reset!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload the page
      await _load();
    } catch (e) {
      debugPrint('❌ Error resetting guesses: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resetting guesses: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _s1.dispose();
    _s2.dispose();
    _s3.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_s1.text.trim().isEmpty || _s2.text.trim().isEmpty || _s3.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all three statements'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    
    try {
      await _controller.submitStatements(
        uid: widget.uid,
        statement1: _s1.text.trim(),
        statement2: _s2.text.trim(),
        statement3: _s3.text.trim(),
        lieIndex: _lieIndex,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Your statements have been saved!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      // Refresh stats
      final stats = await _controller.getMyStats(widget.uid);
      if (mounted) setState(() => _stats = stats);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _guess(TwoTruthsSubmission sub, int shuffledIndex) async {
    debugPrint('🎯 Guess tapped! Shuffled Index: $shuffledIndex, Target: ${sub.uid}');
    HapticFeedback.mediumImpact();
    
    try {
      // Convert shuffled index back to original index
      final originalIndex = sub.getOriginalIndex(shuffledIndex);
      debugPrint('🎯 Shuffled index $shuffledIndex maps to original index $originalIndex');
      
      debugPrint('🎯 Submitting guess...');
      final result = await _controller.submitGuessAndGetResult(
        guesserUid: widget.uid,
        targetUid: sub.uid,
        guessedLieIndex: originalIndex,
      );
      
      debugPrint('🎯 Guess result: ${result.isCorrect ? "CORRECT!" : "WRONG"} (actual lie was ${result.actualLieIndex})');
      
      if (!mounted) return;
      
      // Show result dialog with animation
      await _showResultDialog(result);
      
      // Remove from queue and refresh stats
      setState(() {
        _queue.removeWhere((e) => e.uid == sub.uid);
      });
      
      final stats = await _controller.getMyStats(widget.uid);
      if (mounted) setState(() => _stats = stats);
      
    } catch (e) {
      debugPrint('❌ Error submitting guess: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _showResultDialog(GuessResult result) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: _ResultDialog(result: result),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF667eea).withValues(alpha: 0.15),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const _TwoTruthsSkeletonLoading()
              : Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const Text('🤥', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Two Truths & One Lie',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Stats summary bar
                    _StatsBar(stats: _stats),
                    
                    // Tab bar
                    TabBar(
                      controller: _tabController,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      indicatorColor: theme.colorScheme.primary,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.edit_note),
                          text: 'My Truths',
                        ),
                        Tab(
                          icon: Badge(
                            isLabelVisible: _queue.isNotEmpty,
                            label: Text('${_queue.length}'),
                            child: const Icon(Icons.psychology),
                          ),
                          text: 'Guess',
                        ),
                        const Tab(
                          icon: Icon(Icons.leaderboard),
                          text: 'Leaderboard',
                        ),
                      ],
                    ),
                    
                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMyTruthsTab(theme),
                          _buildGuessTab(theme),
                          _buildLeaderboardTab(theme),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMyTruthsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withValues(alpha: 0.1),
                  const Color(0xFF764ba2).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Write 3 statements about yourself. Two true, one lie. Tap the lie to mark it!',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          Text(
            'Your statements',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          _StatementField(
            label: 'Statement 1',
            controller: _s1,
            selected: _lieIndex == 0,
            onTap: () => setState(() => _lieIndex = 0),
            index: 0,
          ),
          const SizedBox(height: 12),
          _StatementField(
            label: 'Statement 2',
            controller: _s2,
            selected: _lieIndex == 1,
            onTap: () => setState(() => _lieIndex = 1),
            index: 1,
          ),
          const SizedBox(height: 12),
          _StatementField(
            label: 'Statement 3',
            controller: _s3,
            selected: _lieIndex == 2,
            onTap: () => setState(() => _lieIndex = 2),
            index: 2,
          ),
          
          const SizedBox(height: 20),
          
          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_stats.hasSubmitted ? 'Update Statements' : 'Save Statements'),
            ),
          ),
          
          if (_stats.hasSubmitted) ...[
            const SizedBox(height: 24),
            _MySubmissionStats(stats: _stats),
          ],
        ],
      ),
    );
  }

  Widget _buildGuessTab(ThemeData theme) {
    if (_queue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                'All caught up!',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _stats.totalGuesses > 0
                    ? 'You\'ve guessed on all ${_stats.totalGuesses} available submissions!\nWait for more users to submit their statements.'
                    : 'No more statements to guess right now.\nCheck back later for new ones!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const SizedBox(height: 12),
              // Debug button to reset guesses (for testing)
              if (_stats.totalGuesses > 0)
                TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Reset Guesses?'),
                        content: const Text('This will delete all your previous guesses so you can guess again. This is for testing purposes only.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      await _resetGuesses();
                    }
                  },
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Reset My Guesses (Testing)'),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Tap the statement you think is the LIE',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            itemCount: _queue.length,
            controller: PageController(viewportFraction: 0.9),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: _GuessCard(
                  submission: _queue[index],
                  onGuess: (i) => _guess(_queue[index], i),
                  cardIndex: index,
                  totalCards: _queue.length,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTab(ThemeData theme) {
    if (_loadingLeaderboard) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(text: '🎯 Top Guessers'),
              Tab(text: '🤥 Best Liars'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _LeaderboardList(
                  entries: _topGuessers,
                  emptyMessage: 'No guessers yet. Be the first!',
                  statLabel: 'correct',
                  showAccuracy: true,
                ),
                _LeaderboardList(
                  entries: _bestLiars,
                  emptyMessage: 'No liars yet. Submit your statements!',
                  statLabel: 'fooled',
                  showFoolRate: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Stats bar widget showing user's quick stats
class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});

  final TwoTruthsStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.check_circle_outline,
            value: '${stats.correctGuesses}/${stats.totalGuesses}',
            label: 'Correct',
            color: Colors.green,
          ),
          Container(width: 1, height: 30, color: theme.colorScheme.outlineVariant),
          _StatItem(
            icon: Icons.psychology,
            value: stats.totalGuesses > 0 ? '${stats.accuracy.toStringAsFixed(0)}%' : '-',
            label: 'Accuracy',
            color: Colors.blue,
          ),
          Container(width: 1, height: 30, color: theme.colorScheme.outlineVariant),
          _StatItem(
            icon: Icons.sentiment_very_satisfied,
            value: '${stats.peopleFooled}',
            label: 'Fooled',
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// My submission stats widget
class _MySubmissionStats extends StatelessWidget {
  const _MySubmissionStats({required this.stats});

  final TwoTruthsStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Your Submission Stats',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStatCard(
                  value: '${stats.timesGuessedOn}',
                  label: 'Times guessed',
                  icon: Icons.people,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStatCard(
                  value: '${stats.peopleFooled}',
                  label: 'People fooled',
                  icon: Icons.sentiment_very_satisfied,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStatCard(
                  value: stats.timesGuessedOn > 0 ? '${stats.foolRate.toStringAsFixed(0)}%' : '-',
                  label: 'Fool rate',
                  icon: Icons.trending_up,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatementField extends StatelessWidget {
  const _StatementField({
    required this.label,
    required this.controller,
    required this.selected,
    required this.onTap,
    required this.index,
  });

  final String label;
  final TextEditingController controller;
  final bool selected;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLie = selected;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isLie 
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(
          color: isLie ? theme.colorScheme.error : theme.colorScheme.outlineVariant,
          width: isLie ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLie ? theme.colorScheme.error : Colors.transparent,
                border: Border.all(
                  color: isLie ? theme.colorScheme.error : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isLie
                  ? const Icon(Icons.close, size: 18, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isLie) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'THE LIE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Enter your ${isLie ? "lie" : "truth"}...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
                  maxLines: 2,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuessCard extends StatelessWidget {
  const _GuessCard({
    required this.submission,
    required this.onGuess,
    required this.cardIndex,
    required this.totalCards,
  });

  final TwoTruthsSubmission submission;
  final void Function(int index) onGuess;
  final int cardIndex;
  final int totalCards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use shuffled statements if available, otherwise use original order
    final displayStatements = submission.shuffledStatements;
    final items = displayStatements.asMap().entries.toList();
    
    return Card(
      elevation: 8,
      shadowColor: const Color(0xFF667eea).withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                    ),
                    child: const Center(
                      child: Text('?', style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mystery Person',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Find the lie!',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${cardIndex + 1}/$totalCards',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'Which one is the lie?',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Statement buttons
              Expanded(
                child: Column(
                  children: items.map((e) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => onGuess(e.key),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.colorScheme.primaryContainer,
                                ),
                                child: Center(
                                  child: Text(
                                    '${e.key + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: theme.textTheme.bodyMedium,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Result dialog shown after guessing
class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.result});

  final GuessResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = result.isCorrect;
    final submission = result.submission;
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Result icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCorrect ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
              ),
              child: Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                size: 48,
                color: isCorrect ? Colors.green : Colors.red,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              isCorrect ? '🎉 Correct!' : '😅 Wrong!',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              isCorrect 
                  ? 'You found the lie!' 
                  : 'That wasn\'t the lie.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            
            const SizedBox(height: 24),
            
            // Reveal the person
            if (submission.username != null || submission.profileImageB64 != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (submission.profileImageB64 != null)
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: MemoryImage(base64Decode(submission.profileImageB64!)),
                    )
                  else
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        (submission.username ?? '?')[0].toUpperCase(),
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Text(
                    submission.username ?? 'Anonymous',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Show the lie
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.close, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        'The lie was:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    submission.statements[result.actualLieIndex],
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Leaderboard list widget
class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({
    required this.entries,
    required this.emptyMessage,
    required this.statLabel,
    this.showAccuracy = false,
    this.showFoolRate = false,
  });

  final List<TwoTruthsLeaderboardEntry> entries;
  final String emptyMessage;
  final String statLabel;
  final bool showAccuracy;
  final bool showFoolRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isTop3 = index < 3;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: isTop3 ? _getRankColor(index).withValues(alpha: 0.1) : null,
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    isTop3 ? _getRankEmoji(index) : '#${index + 1}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (entry.profileImageB64 != null)
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: MemoryImage(base64Decode(entry.profileImageB64!)),
                  )
                else
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      entry.username[0].toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              entry.username,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              showAccuracy 
                  ? '${entry.accuracy.toStringAsFixed(0)}% accuracy'
                  : showFoolRate 
                      ? '${entry.foolRate.toStringAsFixed(0)}% fool rate'
                      : '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                showFoolRate 
                    ? '${entry.peopleFooled} $statLabel'
                    : '${entry.correctGuesses} $statLabel',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0: return Colors.amber;
      case 1: return Colors.grey;
      case 2: return Colors.brown;
      default: return Colors.transparent;
    }
  }

  String _getRankEmoji(int index) {
    switch (index) {
      case 0: return '🥇';
      case 1: return '🥈';
      case 2: return '🥉';
      default: return '#${index + 1}';
    }
  }
}

/// Skeleton loading widget for Two Truths One Lie page
class _TwoTruthsSkeletonLoading extends StatelessWidget {
  const _TwoTruthsSkeletonLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const Text('🤥', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Two Truths & One Lie',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Stats bar skeleton
        Shimmer(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItemSkeleton(),
                Container(width: 1, height: 30, color: theme.colorScheme.outlineVariant),
                _buildStatItemSkeleton(),
                Container(width: 1, height: 30, color: theme.colorScheme.outlineVariant),
                _buildStatItemSkeleton(),
              ],
            ),
          ),
        ),

        // Tab bar skeleton
        Shimmer(
          child: Container(
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildTabSkeleton()),
                Expanded(child: _buildTabSkeleton()),
                Expanded(child: _buildTabSkeleton()),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Content skeleton (My Truths tab style)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Shimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructions card skeleton
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF667eea).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SkeletonBox(width: 24, height: 24, borderRadius: 4),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              SkeletonBox(width: double.infinity, height: 12, borderRadius: 6),
                              SizedBox(height: 6),
                              SkeletonBox(width: 200, height: 12, borderRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // "Your statements" label skeleton
                  const SkeletonBox(width: 120, height: 16, borderRadius: 8),

                  const SizedBox(height: 12),

                  // Statement fields skeleton
                  _buildStatementFieldSkeleton(theme),
                  const SizedBox(height: 12),
                  _buildStatementFieldSkeleton(theme),
                  const SizedBox(height: 12),
                  _buildStatementFieldSkeleton(theme),

                  const SizedBox(height: 20),

                  // Save button skeleton
                  const SkeletonBox(
                    width: double.infinity,
                    height: 52,
                    borderRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItemSkeleton() {
    return Column(
      children: const [
        SkeletonBox(width: 18, height: 18, isCircle: true),
        SizedBox(height: 4),
        SkeletonBox(width: 40, height: 16, borderRadius: 8),
        SizedBox(height: 2),
        SkeletonBox(width: 50, height: 10, borderRadius: 5),
      ],
    );
  }

  Widget _buildTabSkeleton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        SkeletonBox(width: 24, height: 24, borderRadius: 6),
        SizedBox(height: 4),
        SkeletonBox(width: 60, height: 12, borderRadius: 6),
      ],
    );
  }

  Widget _buildStatementFieldSkeleton(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 28, height: 28, isCircle: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 80, height: 12, borderRadius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: double.infinity, height: 14, borderRadius: 7),
                SizedBox(height: 6),
                SkeletonBox(width: 150, height: 14, borderRadius: 7),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
