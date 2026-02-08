import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../auth/app_user.dart';

enum SwipeAction { match, friend, skip }

typedef OnSwipe = Future<void> Function(AppUser user, SwipeAction action);

typedef OnViewProfile = void Function(AppUser user);

class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.users,
    required this.onSwipe,
    required this.onViewProfile,
    this.mutualInterestsByUid = const <String, List<String>>{},
  });

  final List<AppUser> users;

  /// Map candidate uid -> mutual interests with current user.
  final Map<String, List<String>> mutualInterestsByUid;

  final OnSwipe onSwipe;
  final OnViewProfile onViewProfile;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck> {
  late List<AppUser> _queue;
  bool _busy = false;
  final AudioPlayer _skipSoundPlayer = AudioPlayer();
  final AudioPlayer _friendSoundPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _queue = List.of(widget.users);
  }

  @override
  void dispose() {
    _skipSoundPlayer.dispose();
    _friendSoundPlayer.dispose();
    super.dispose();
  }

  void _playSkipSound() {
    _skipSoundPlayer.stop();
    _skipSoundPlayer.play(AssetSource('sounds/swipe_next.mpeg'));
  }

  void _playFriendSound() {
    _friendSoundPlayer.stop();
    _friendSoundPlayer.play(AssetSource('sounds/acha_ji.mpeg'));
  }

  @override
  void didUpdateWidget(covariant SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.users, widget.users)) {
      // Replace the queue with the latest filtered/sorted list from parent.
      _queue = List.of(widget.users);
    }
  }

  AppUser? get _current => _queue.isEmpty ? null : _queue.first;

  AppUser? _removeCurrent() {
    if (!mounted) return null;
    if (_queue.isEmpty) return null;
    final removed = _queue.first;
    setState(() {
      _queue.removeAt(0);
    });
    return removed;
  }

  void _reinsertFront(AppUser u) {
    if (!mounted) return;
    if (_queue.isNotEmpty && _queue.first.uid == u.uid) return;
    setState(() {
      _queue.insert(0, u);
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  void _handleSwipe(AppUser u, SwipeAction action) {
    if (_busy) return;

    final removed = _removeCurrent();
    if (removed == null) return;

    // Skip: remove immediately, but still notify parent so it can persist and
    // filter the user out permanently.
    if (action == SwipeAction.skip) {
      _toast('Next');
      widget.onSwipe(u, action).catchError((_) {});
      return;
    }

    // Friend/Match: optimistic remove, but rollback if the write fails.
    setState(() => _busy = true);
    widget.onSwipe(u, action).then((_) {
      _toast(action == SwipeAction.friend ? 'Friend request sent' : 'Match request sent');
    }).catchError((e) {
      _reinsertFront(removed);
      _toast('Failed. Try again');
    }).whenComplete(() {
      if (mounted) setState(() => _busy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = _current;

    if (u == null) {
      return Center(
        child: Text(
          'No one new right now',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final mutual = widget.mutualInterestsByUid[u.uid] ?? const <String>[];

    return Column(
      children: [
        // Card area - takes available space
        Expanded(
          child: Stack(
            children: [
              // Background card peek (next user)
              if (_queue.length > 1)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Transform.scale(
                      scale: 0.97,
                      child: _ProfileCard(
                        user: _queue[1],
                        mutualInterests: widget.mutualInterestsByUid[_queue[1].uid] ?? const <String>[],
                        onTap: () => widget.onViewProfile(_queue[1]),
                      ),
                    ),
                  ),
                ),

              // Top draggable card
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _SwipeableCard(
                    user: u,
                    mutualInterests: mutual,
                    enabled: !_busy,
                    onFriend: () {
                      _playFriendSound();
                      _handleSwipe(u, SwipeAction.friend);
                    },
                    onSkip: () {
                      _playSkipSound();
                      _handleSwipe(u, SwipeAction.skip);
                    },
                    onTap: () => widget.onViewProfile(u),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Action buttons - fixed at bottom, above nav bar
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionCircle(
                  label: 'Friend',
                  icon: Icons.person_add_alt_1,
                  color: theme.colorScheme.primary,
                  onPressed: _busy ? null : () => _handleSwipe(u, SwipeAction.friend),
                ),
                const SizedBox(width: 32),
                _ActionCircle(
                  label: 'Match',
                  icon: Icons.favorite,
                  color: theme.colorScheme.secondary,
                  onPressed: _busy ? null : () => _handleSwipe(u, SwipeAction.match),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: theme.colorScheme.surface,
            shape: const CircleBorder(),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: onPressed != null ? color : color.withValues(alpha: 0.4), size: 30),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeableCard extends StatefulWidget {
  const _SwipeableCard({
    required this.user,
    required this.mutualInterests,
    required this.enabled,
    required this.onFriend,
    required this.onSkip,
    required this.onTap,
  });

  final AppUser user;
  final List<String> mutualInterests;
  final bool enabled;
  final VoidCallback onFriend;
  final VoidCallback onSkip;
  final VoidCallback onTap;

  @override
  State<_SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<_SwipeableCard> {
  Offset _drag = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dx = _drag.dx;
    final rotation = (dx / size.width) * 0.25;

    final label = dx.abs() < 18
        ? null
        : dx > 0
            ? _SwipeLabel.skip
            : _SwipeLabel.friend;

    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: widget.enabled
          ? (d) => setState(() => _drag += d.delta)
          : null,
      onPanEnd: widget.enabled
          ? (d) {
              final threshold = size.width * 0.22;
              if (_drag.dx > threshold) {
                // Swipe right = next/skip
                widget.onSkip();
              } else if (_drag.dx < -threshold) {
                // Swipe left = friend request
                widget.onFriend();
              }
              setState(() => _drag = Offset.zero);
            }
          : null,
      child: Transform.translate(
        offset: _drag,
        child: Transform.rotate(
          angle: rotation,
          child: _ProfileCard(
            user: widget.user,
            mutualInterests: widget.mutualInterests,
            overlayLabel: label,
          ),
        ),
      ),
    );
  }
}

enum _SwipeLabel { skip, friend }

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.user,
    required this.mutualInterests,
    this.overlayLabel,
    this.onTap,
  });

  final AppUser user;
  final List<String> mutualInterests;
  final _SwipeLabel? overlayLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final image = user.profileImageBytes == null
        ? null
        : MemoryImage(Uint8List.fromList(user.profileImageBytes!));
    
    final hasImage = image != null;

    // Colors that adapt based on whether we have an image or not
    // With image: always use white text (over dark gradient)
    // Without image: use theme-aware colors
    final Color primaryTextColor = hasImage 
        ? Colors.white 
        : theme.colorScheme.onSurface;
    final Color secondaryTextColor = hasImage 
        ? Colors.white.withValues(alpha: 0.9) 
        : theme.colorScheme.onSurfaceVariant;
    final Color chipBgColor = hasImage
        ? Colors.white.withValues(alpha: 0.15)
        : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08));
    final Color chipTextColor = hasImage
        ? Colors.white
        : theme.colorScheme.onSurface;
    final Color chipBorderColor = hasImage
        ? Colors.white.withValues(alpha: 0.25)
        : theme.colorScheme.outline.withValues(alpha: 0.3);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      elevation: isDark ? 8 : 4,
      shadowColor: isDark ? Colors.black54 : Colors.black26,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo or beautiful placeholder
            if (hasImage)
              Image(image: image, fit: BoxFit.cover)
            else
              // Theme-aware placeholder design
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            theme.colorScheme.surfaceContainerHighest,
                            theme.colorScheme.surfaceContainerHigh,
                          ]
                        : [
                            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                            theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                          ],
                  ),
                ),
                child: Column(
                  children: [
                    // Top section with avatar
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      theme.colorScheme.primary.withValues(alpha: 0.4),
                                      theme.colorScheme.secondary.withValues(alpha: 0.3),
                                    ]
                                  : [
                                      theme.colorScheme.primary.withValues(alpha: 0.2),
                                      theme.colorScheme.secondary.withValues(alpha: 0.15),
                                    ],
                            ),
                            border: Border.all(
                              color: isDark 
                                  ? theme.colorScheme.outline.withValues(alpha: 0.3)
                                  : theme.colorScheme.primary.withValues(alpha: 0.3),
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: 64,
                            color: isDark
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                                : theme.colorScheme.primary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                    // Bottom section reserved for text overlay
                    const Expanded(flex: 2, child: SizedBox()),
                  ],
                ),
              ),

            // Gradient for text readability (only when there's an image)
            if (hasImage)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x18000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.0, 0.3, 0.5, 1.0],
                  ),
                ),
              ),

            // Like/Nope overlay label
            if (overlayLabel != null)
              Positioned(
                top: 22,
                left: overlayLabel == _SwipeLabel.skip ? 22 : null,
                right: overlayLabel == _SwipeLabel.friend ? 22 : null,
                child: Transform.rotate(
                  angle: overlayLabel == _SwipeLabel.skip ? -0.18 : 0.18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: (overlayLabel == _SwipeLabel.skip
                              ? Colors.red
                              : Colors.green)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        width: 3,
                        color: overlayLabel == _SwipeLabel.skip
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    child: Text(
                      overlayLabel == _SwipeLabel.skip ? 'NEXT' : 'FRIEND',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: overlayLabel == _SwipeLabel.skip
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom profile summary with glassmorphism effect for no-image cards
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: hasImage
                    ? null
                    : BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.85),
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Username with shadow for readability
                    Text(
                      user.username,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: primaryTextColor,
                        fontWeight: FontWeight.w900,
                        shadows: hasImage
                            ? [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Bio
                    Text(
                      user.bio.isEmpty ? user.gender.label : user.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: secondaryTextColor,
                        shadows: hasImage
                            ? [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Mutual interests highlight
                    if (mutualInterests.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? theme.colorScheme.primary.withValues(alpha: 0.25)
                              : theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: isDark
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Shared: ${mutualInterests.take(3).join(', ')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Interest chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(
                          label: user.gender.label,
                          icon: Icons.person_outline,
                          bgColor: chipBgColor,
                          textColor: chipTextColor,
                          borderColor: chipBorderColor,
                        ),
                        for (final i in user.interests.take(3))
                          _buildChip(
                            label: i,
                            bgColor: chipBgColor,
                            textColor: chipTextColor,
                            borderColor: chipBorderColor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    IconData? icon,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
