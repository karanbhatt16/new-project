import 'package:flutter/material.dart';

import '../../auth/firebase_auth_controller.dart';
import 'login_page.dart';

/// Beautiful landing page that introduces the app and its features.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.controller});

  final FirebaseAuthController controller;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            LoginPage(controller: widget.controller),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                    const Color(0xFF0F3460),
                  ]
                : [
                    const Color(0xFFF8F9FF),
                    const Color(0xFFE8EAFF),
                    const Color(0xFFD4D8FF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with Get Started button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'vibeU',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    // Get Started Button
                    FilledButton.icon(
                      onPressed: _navigateToLogin,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Get Started'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Column(
                        children: [
                          SizedBox(height: size.height * 0.06),

                          // Hero section
                          _buildHeroSection(theme, isDark),

                          const SizedBox(height: 50),

                          // Features section
                          _buildFeaturesSection(theme, isDark),

                          const SizedBox(height: 50),

                          // Stats section
                          _buildStatsSection(theme, isDark),

                          const SizedBox(height: 50),

                          // CTA section
                          _buildCtaSection(theme),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Animated hearts decoration
        SizedBox(
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 20,
                top: 10,
                child: _buildFloatingHeart(40, Colors.pink.withValues(alpha: 0.3), 0),
              ),
              Positioned(
                right: 30,
                top: 20,
                child: _buildFloatingHeart(30, Colors.purple.withValues(alpha: 0.3), 0.5),
              ),
              Positioned(
                left: 60,
                bottom: 10,
                child: _buildFloatingHeart(25, Colors.red.withValues(alpha: 0.3), 1.0),
              ),
              Positioned(
                right: 50,
                bottom: 20,
                child: _buildFloatingHeart(35, Colors.pink.withValues(alpha: 0.3), 1.5),
              ),
              // Center icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        // Tagline
        Text(
          'Find Your Vibe',
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'On Campus',
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1.1,
            foreground: Paint()
              ..shader = LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
          ),
        ),

        const SizedBox(height: 20),

        // Description
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Text(
            'Connect with students from your campus. Make friends, find your match, and share moments — all in a safe, verified community.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingHeart(double size, Color color, double delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 2000 + (delay * 500).toInt()),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -10 * (0.5 - (value - 0.5).abs())),
          child: child,
        );
      },
      child: Icon(
        Icons.favorite_rounded,
        size: size,
        color: color,
      ),
    );
  }

  Widget _buildFeaturesSection(ThemeData theme, bool isDark) {
    final features = [
      _FeatureItem(
        icon: Icons.verified_user_rounded,
        title: 'Campus Verified',
        description: 'Only students with valid college email can join',
        gradient: [Colors.blue, Colors.cyan],
      ),
      _FeatureItem(
        icon: Icons.forum_rounded,
        title: 'Real Connections',
        description: 'Chat, share posts, and build genuine friendships',
        gradient: [Colors.purple, Colors.pink],
      ),
      _FeatureItem(
        icon: Icons.favorite_rounded,
        title: 'Find Your Match',
        description: 'Swipe to discover people who share your vibe',
        gradient: [Colors.red, Colors.orange],
      ),
      _FeatureItem(
        icon: Icons.shield_rounded,
        title: 'Safe & Secure',
        description: 'End-to-end encrypted chats and verified profiles',
        gradient: [Colors.green, Colors.teal],
      ),
    ];

    return Column(
      children: [
        Text(
          'Why vibeU?',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: features
              .map((f) => _buildFeatureCard(f, theme, isDark))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(_FeatureItem feature, ThemeData theme, bool isDark) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: feature.gradient),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              feature.icon,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            feature.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            feature.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('500+', 'Students', theme),
          _buildDivider(isDark),
          _buildStatItem('1K+', 'Connections', theme),
          _buildDivider(isDark),
          _buildStatItem('100%', 'Verified', theme),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 40,
      width: 1,
      color: isDark ? Colors.white24 : Colors.black12,
    );
  }

  Widget _buildCtaSection(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Ready to find your vibe?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _navigateToLogin,
          icon: const Icon(Icons.rocket_launch_rounded),
          label: const Text('Join vibeU Today'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Campus-only • Safe • Respectful',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;

  _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}
