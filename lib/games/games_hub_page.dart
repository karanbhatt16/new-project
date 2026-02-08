import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/firebase_auth_controller.dart';
import '../chat/firestore_chat_controller.dart';
import '../social/firestore_social_graph_controller.dart';
import 'run_for_your_type/run_for_your_type_page.dart';
import 'run_for_your_type/game_controller.dart';
import 'two_truths_one_lie/two_truths_one_lie_page.dart';
import 'would_you_rather/would_you_rather_page.dart';

/// Hub page for all Valentine games.
/// 
/// This page lists all available games and allows users to navigate to them.
/// New games can be easily added to the [_games] list.
class GamesHubPage extends StatefulWidget {
  const GamesHubPage({
    super.key,
    required this.uid,
    required this.gender,
    required this.auth,
    this.social,
    this.chat,
    this.showBackButton = true,
  });

  final String uid;
  final String gender;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController? social;
  final FirestoreChatController? chat;
  final bool showBackButton;

  @override
  State<GamesHubPage> createState() => _GamesHubPageState();
}

class _GamesHubPageState extends State<GamesHubPage> {
  final _runForYourTypeController = RunForYourTypeController();

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
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (widget.showBackButton) ...[
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Text('🎮', style: TextStyle(fontSize: 32)),
                          const SizedBox(width: 12),
                          Text(
                            'Valentine Games',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Play fun games and find your perfect match!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Games list
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Game 1: Run For Your Type
                    _GameCard(
                      title: 'Run For Your Type',
                      description: 'Answer questions about yourself and what you\'re looking for. See your matches on Valentine\'s Day!',
                      emoji: '💘',
                      gradientColors: const [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
                      statusWidget: _buildRunForYourTypeStatus(),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RunForYourTypePage(
                              uid: widget.uid,
                              gender: widget.gender,
                              auth: widget.auth,
                              social: widget.social,
                              chat: widget.chat,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Game 2: Two Truths & One Lie
                    _GameCard(
                      title: 'Two Truths & One Lie',
                      description: 'Share 3 facts about yourself. Can others guess which one is the lie?',
                      emoji: '🤥',
                      gradientColors: const [Color(0xFF667eea), Color(0xFF764ba2)],
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TwoTruthsOneLiePage(
                              uid: widget.uid,
                              auth: widget.auth,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Game 3: Would You Rather
                    _GameCard(
                      title: 'Would You Rather',
                      description: 'Answer fun "would you rather" questions and see who thinks like you!',
                      emoji: '🤔',
                      gradientColors: const [Color(0xFF11998e), Color(0xFF38ef7d)],
                      onTap: () {
                        if (widget.social == null || widget.chat == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Unable to start game. Please try again.')),
                          );
                          return;
                        }
                        final email = widget.auth.firebaseUser?.email ?? '';
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WouldYouRatherPage(
                              uid: widget.uid,
                              email: email,
                              auth: widget.auth,
                              social: widget.social!,
                              chat: widget.chat!,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Game 4: Coming Soon - Love Language Quiz
                    _GameCard(
                      title: 'Love Language Quiz',
                      description: 'Discover your love language and find someone who speaks it!',
                      emoji: '💕',
                      gradientColors: const [Color(0xFFf093fb), Color(0xFFf5576c)],
                      isComingSoon: true,
                      onTap: () {
                        _showComingSoonDialog(context, 'Love Language Quiz');
                      },
                    ),

                    const SizedBox(height: 16),

                    // Game 5: Coming Soon - Compatibility Quiz
                    _GameCard(
                      title: 'Compatibility Quiz',
                      description: 'Answer personality questions and get matched with compatible people!',
                      emoji: '🎯',
                      gradientColors: const [Color(0xFFfc4a1a), Color(0xFFf7b733)],
                      isComingSoon: true,
                      onTap: () {
                        _showComingSoonDialog(context, 'Compatibility Quiz');
                      },
                    ),

                    const SizedBox(height: 32),

                    // Suggest a game section
                    _SuggestGameCard(theme: theme),

                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunForYourTypeStatus() {
    return FutureBuilder<bool>(
      future: _runForYourTypeController.hasUserSubmitted(widget.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final hasPlayed = snapshot.data!;
        final canViewResults = _runForYourTypeController.shouldRevealResults();

        if (hasPlayed) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  canViewResults ? 'View Results' : 'Played ✓',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill, size: 14, color: Colors.orange),
              SizedBox(width: 4),
              Text(
                'Play Now',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showComingSoonDialog(BuildContext context, String gameName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Text('🚀 '),
            Text(gameName),
          ],
        ),
        content: const Text(
          'This game is coming soon! Stay tuned for updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Card widget for displaying a game in the hub.
class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.description,
    required this.emoji,
    required this.gradientColors,
    required this.onTap,
    this.statusWidget,
    this.isComingSoon = false,
  });

  final String title;
  final String description;
  final String emoji;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final Widget? statusWidget;
  final bool isComingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isComingSoon
                  ? [Colors.grey.shade400, Colors.grey.shade500]
                  : gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isComingSoon ? Colors.grey : gradientColors.first)
                    .withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Emoji icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: TextStyle(
                      fontSize: 32,
                      color: isComingSoon ? Colors.white54 : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isComingSoon)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'SOON',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (statusWidget != null) statusWidget!,
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.8),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card for suggesting new games.
class _SuggestGameCard extends StatelessWidget {
  const _SuggestGameCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          const Text('💡', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'Have a game idea?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'We\'re always looking for fun new games to add!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Implement feedback/suggestion functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Suggestion feature coming soon! 💡'),
                ),
              );
            },
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Suggest a Game'),
          ),
        ],
      ),
    );
  }
}
