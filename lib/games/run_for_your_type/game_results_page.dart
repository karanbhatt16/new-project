import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/firebase_auth_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../share_game_dialog.dart';
import 'game_controller.dart';
import 'game_models.dart';

/// Share message for inviting friends to play.
const String _shareMessage = '''💘 Run For Your Type - Valentine's Game! 💘

Hey! Come play "Run For Your Type" with me! 🎮

Answer fun questions about yourself and what you're looking for in a match. Results are revealed on Valentine's Day!

🎯 Find your perfect match
👥 See compatibility scores
💕 Play now in the Games tab!''';

/// Results page showing matches sorted by compatibility.
/// 
/// Only shows real results after Feb 14, 2026.
/// Before that, shows a countdown.
class GameResultsPage extends StatefulWidget {
  const GameResultsPage({
    super.key,
    required this.uid,
    required this.gender,
    required this.auth,
    required this.controller,
    this.social,
    this.chat,
  });

  final String uid;
  final String gender;
  final FirebaseAuthController auth;
  final RunForYourTypeController controller;
  final FirestoreSocialGraphController? social;
  final FirestoreChatController? chat;

  @override
  State<GameResultsPage> createState() => _GameResultsPageState();
}

class _GameResultsPageState extends State<GameResultsPage> 
    with SingleTickerProviderStateMixin {
  List<MatchResult>? _results;
  bool _loading = true;
  String? _error;
  
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadResults();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _shareGame() async {
    if (widget.social == null || widget.chat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share feature not available')),
      );
      return;
    }

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

  Future<void> _loadResults() async {
    // Check if results should be revealed
    if (!widget.controller.shouldRevealResults()) {
      setState(() => _loading = false);
      return;
    }

    try {
      final results = await widget.controller.getMatchResults(
        uid: widget.uid,
        gender: widget.gender,
        getUserProfile: widget.auth.publicProfileByUid,
      );
      
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
        _animController.forward();
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load results: $e';
          _loading = false;
        });
      }
    }
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
              theme.colorScheme.primary.withValues(alpha: 0.15),
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
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('Finding your matches... 💕'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadResults();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Check if results should be revealed
    if (!widget.controller.shouldRevealResults()) {
      return _buildCountdownView(theme);
    }

    if (_results == null || _results!.isEmpty) {
      return _buildNoMatchesView(theme);
    }

    return _buildResultsView(theme);
  }

  Widget _buildCountdownView(ThemeData theme) {
    final countdown = widget.controller.getCountdownToReveal();
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔒', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 24),
          
          Text(
            'Results Locked',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'Your matches will be revealed on Valentine\'s Day!',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 40),
          
          _CountdownDisplay(countdown: countdown, theme: theme),
          
          const SizedBox(height: 40),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '💝 February 14, 2026 💝',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mark your calendar!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatchesView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('😢', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 24),
          
          Text(
            'No Matches Yet',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'No one from the opposite gender has played the game yet. Share with friends to find your Valentine!',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 40),
          
          FilledButton.icon(
            onPressed: _shareGame,
            icon: const Icon(Icons.share),
            label: const Text('Invite Friends to Play'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          
          const SizedBox(height: 8),
          Text(
            'More players = more matches! 💕',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          
          const SizedBox(height: 16),
          
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('💘', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 16),
                Text(
                  'Your Matches',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sorted by compatibility',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_results!.length} ${_results!.length == 1 ? 'match' : 'matches'} found',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Top 3 podium (if we have enough matches)
        if (_results!.length >= 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _TopMatchesPodium(
                results: _results!.take(3).toList(),
                theme: theme,
                animController: _animController,
              ),
            ),
          ),
        
        // Divider
        if (_results!.length > 3)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Other Matches',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                ],
              ),
            ),
          ),
        
        // Rest of the matches
        if (_results!.length > 3)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final result = _results![index + 3];
                  return _MatchListTile(
                    result: result,
                    rank: index + 4,
                    theme: theme,
                    delay: index * 100,
                    animController: _animController,
                  );
                },
                childCount: _results!.length - 3,
              ),
            ),
          ),
        
        // Bottom padding and back button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// HELPER WIDGETS
// ============================================================

class _CountdownDisplay extends StatelessWidget {
  const _CountdownDisplay({
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
    final seconds = countdown.inSeconds % 60;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TimeBox(value: days, label: 'Days', theme: theme),
        const SizedBox(width: 8),
        Text(':', style: theme.textTheme.headlineMedium),
        const SizedBox(width: 8),
        _TimeBox(value: hours, label: 'Hours', theme: theme),
        const SizedBox(width: 8),
        Text(':', style: theme.textTheme.headlineMedium),
        const SizedBox(width: 8),
        _TimeBox(value: minutes, label: 'Mins', theme: theme),
        const SizedBox(width: 8),
        Text(':', style: theme.textTheme.headlineMedium),
        const SizedBox(width: 8),
        _TimeBox(value: seconds, label: 'Secs', theme: theme),
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
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
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopMatchesPodium extends StatelessWidget {
  const _TopMatchesPodium({
    required this.results,
    required this.theme,
    required this.animController,
  });

  final List<MatchResult> results;
  final ThemeData theme;
  final AnimationController animController;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    
    // Reorder for podium: 2nd, 1st, 3rd
    final podiumOrder = <MatchResult?>[];
    if (results.length >= 2) podiumOrder.add(results[1]); else podiumOrder.add(null);
    podiumOrder.add(results[0]); // 1st is always there
    if (results.length >= 3) podiumOrder.add(results[2]); else podiumOrder.add(null);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd place
        Expanded(
          child: podiumOrder[0] != null
              ? _PodiumItem(
                  result: podiumOrder[0]!,
                  rank: 2,
                  height: 100,
                  theme: theme,
                  animController: animController,
                  delay: 200,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        // 1st place
        Expanded(
          child: _PodiumItem(
            result: podiumOrder[1]!,
            rank: 1,
            height: 130,
            theme: theme,
            animController: animController,
            delay: 0,
          ),
        ),
        const SizedBox(width: 8),
        // 3rd place
        Expanded(
          child: podiumOrder[2] != null
              ? _PodiumItem(
                  result: podiumOrder[2]!,
                  rank: 3,
                  height: 80,
                  theme: theme,
                  animController: animController,
                  delay: 400,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _PodiumItem extends StatelessWidget {
  const _PodiumItem({
    required this.result,
    required this.rank,
    required this.height,
    required this.theme,
    required this.animController,
    required this.delay,
  });

  final MatchResult result;
  final int rank;
  final double height;
  final ThemeData theme;
  final AnimationController animController;
  final int delay;

  Color get _rankColor {
    switch (rank) {
      case 1: return Colors.amber;
      case 2: return Colors.grey.shade400;
      case 3: return Colors.brown.shade300;
      default: return theme.colorScheme.primary;
    }
  }

  String get _rankEmoji {
    switch (rank) {
      case 1: return '👑';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '🏅';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animController,
      builder: (context, child) {
        final delayedValue = ((animController.value - delay / 1000) * 2).clamp(0.0, 1.0);
        
        return Transform.translate(
          offset: Offset(0, 50 * (1 - delayedValue)),
          child: Opacity(
            opacity: delayedValue,
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          // Profile avatar
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: rank == 1 ? 90 : 70,
                height: rank == 1 ? 90 : 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _rankColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _rankColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: result.profileImageBytes != null
                      ? Image.memory(
                          Uint8List.fromList(result.profileImageBytes!),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.person,
                            size: rank == 1 ? 40 : 30,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              Positioned(
                top: -5,
                child: Text(_rankEmoji, style: TextStyle(fontSize: rank == 1 ? 24 : 18)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Name
          Text(
            result.otherUsername,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          // Match percentage
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getMatchColor(result.matchPercentage).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${result.matchPercentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: rank == 1 ? 18 : 14,
                fontWeight: FontWeight.bold,
                color: _getMatchColor(result.matchPercentage),
              ),
            ),
          ),
          const SizedBox(height: 4),
          
          // Match label
          Text(
            result.matchLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Podium stand
          Container(
            height: height,
            decoration: BoxDecoration(
              color: _rankColor.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border.all(color: _rankColor, width: 2),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _rankColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMatchColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.lightGreen;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }
}

class _MatchListTile extends StatelessWidget {
  const _MatchListTile({
    required this.result,
    required this.rank,
    required this.theme,
    required this.delay,
    required this.animController,
  });

  final MatchResult result;
  final int rank;
  final ThemeData theme;
  final int delay;
  final AnimationController animController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animController,
      builder: (context, child) {
        final delayedValue = ((animController.value - delay / 1000) * 2).clamp(0.0, 1.0);
        
        return Transform.translate(
          offset: Offset(30 * (1 - delayedValue), 0),
          child: Opacity(
            opacity: delayedValue,
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#$rank',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 24,
                backgroundImage: result.profileImageBytes != null
                    ? MemoryImage(Uint8List.fromList(result.profileImageBytes!))
                    : null,
                child: result.profileImageBytes == null
                    ? const Icon(Icons.person)
                    : null,
              ),
            ],
          ),
          title: Text(
            result.otherUsername,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            result.matchLabel,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getMatchColor(result.matchPercentage).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${result.matchPercentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getMatchColor(result.matchPercentage),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getMatchColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.lightGreen;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }
}
