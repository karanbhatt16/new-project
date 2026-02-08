import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef ReactionToggle = Future<void> Function(String emoji);

/// WhatsApp-style reaction badge that appears at the bottom of a message bubble.
/// Compact pill with emoji(s) and count.
/// Features animations and haptic feedback for better UX.
class ReactionRow extends StatefulWidget {
  const ReactionRow({
    super.key,
    required this.reactions,
    required this.myUid,
    required this.onToggle,
    this.isMe = false,
  });

  final Map<String, List<String>> reactions;
  final String myUid;
  final ReactionToggle onToggle;
  final bool isMe;

  @override
  State<ReactionRow> createState() => _ReactionRowState();
}

class _ReactionRowState extends State<ReactionRow> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(ReactionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate when reactions change
    if (oldWidget.reactions.length != widget.reactions.length ||
        _reactionsChanged(oldWidget.reactions, widget.reactions)) {
      _animController.reset();
      _animController.forward();
      // Haptic feedback when reactions update
      HapticFeedback.lightImpact();
    }
  }

  bool _reactionsChanged(Map<String, List<String>> old, Map<String, List<String>> current) {
    if (old.keys.length != current.keys.length) return true;
    for (final key in old.keys) {
      if (!current.containsKey(key)) return true;
      if (old[key]!.length != current[key]!.length) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Sort by count (descending)
    final entries = widget.reactions.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // Total reaction count
    final totalCount = entries.fold<int>(0, (sum, e) => sum + e.value.length);
    
    // Check if current user reacted
    final iReacted = entries.any((e) => e.value.contains(widget.myUid));

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _showReactionDetails(context, entries, theme);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF1F2C34) // WhatsApp dark mode reaction bg
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: iReacted 
                  ? theme.colorScheme.primary.withValues(alpha: 0.7)
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.15)),
              width: iReacted ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show emojis (up to 3) with slight overlap effect
              for (int i = 0; i < entries.length && i < 3; i++)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: Duration(milliseconds: 200 + (i * 50)),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: child,
                  ),
                  child: Text(
                    entries[i].key,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              // Show count only when more than 1 reaction
              if (totalCount > 1) ...[
                const SizedBox(width: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: Text(
                    totalCount.toString(),
                    key: ValueKey(totalCount),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showReactionDetails(BuildContext context, List<MapEntry<String, List<String>>> entries, ThemeData theme) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _ReactionDetailsSheet(
          entries: entries,
          theme: theme,
          myUid: widget.myUid,
          onToggle: widget.onToggle,
        );
      },
    );
  }
}

/// Animated bottom sheet showing reaction details
class _ReactionDetailsSheet extends StatefulWidget {
  const _ReactionDetailsSheet({
    required this.entries,
    required this.theme,
    required this.myUid,
    required this.onToggle,
  });

  final List<MapEntry<String, List<String>>> entries;
  final ThemeData theme;
  final String myUid;
  final ReactionToggle onToggle;

  @override
  State<_ReactionDetailsSheet> createState() => _ReactionDetailsSheetState();
}

class _ReactionDetailsSheetState extends State<_ReactionDetailsSheet> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final allCount = widget.entries.fold<int>(0, (sum, e) => sum + e.value.length);
    
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
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
              color: widget.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Emoji tabs row - horizontally scrollable
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // All tab
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTabIndex = 0);
                  },
                  child: _AnimatedReactionTab(
                    emoji: 'All',
                    count: allCount,
                    isSelected: _selectedTabIndex == 0,
                    theme: widget.theme,
                  ),
                ),
                const SizedBox(width: 8),
                // Individual emoji tabs
                for (int i = 0; i < widget.entries.length && i < 6; i++) ...[
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTabIndex = i + 1);
                    },
                    child: _AnimatedReactionTab(
                      emoji: widget.entries[i].key,
                      count: widget.entries[i].value.length,
                      isSelected: _selectedTabIndex == i + 1,
                      theme: widget.theme,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: widget.theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          // Reaction list with animations
          ...(_selectedTabIndex == 0 ? widget.entries : [widget.entries[_selectedTabIndex - 1]])
              .asMap()
              .entries
              .map((indexedEntry) {
            final e = indexedEntry.value;
            final index = indexedEntry.key;
            final iMine = e.value.contains(widget.myUid);
            
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 200 + (index * 50)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Hero(
                  tag: 'reaction_${e.key}',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(e.key, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                ),
                title: Text(
                  iMine ? 'You' : '${e.value.length} ${e.value.length == 1 ? 'person' : 'people'}',
                  style: widget.theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: iMine 
                    ? Text(
                        'Tap to remove',
                        style: widget.theme.textTheme.bodySmall?.copyWith(
                          color: widget.theme.colorScheme.primary,
                        ),
                      )
                    : null,
                trailing: iMine
                    ? Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: widget.theme.colorScheme.error,
                        ),
                      )
                    : null,
                onTap: iMine
                    ? () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop();
                        widget.onToggle(e.key);
                      }
                    : null,
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Animated tab for reaction filtering in bottom sheet
class _AnimatedReactionTab extends StatelessWidget {
  const _AnimatedReactionTab({
    required this.emoji,
    required this.count,
    required this.isSelected,
    required this.theme,
  });

  final String emoji;
  final int count;
  final bool isSelected;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected 
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: isSelected ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              emoji,
              style: TextStyle(
                fontSize: emoji == 'All' ? 14 : 20,
                fontWeight: emoji == 'All' ? FontWeight.w700 : FontWeight.normal,
                color: emoji == 'All' 
                    ? (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            child: Text(count.toString()),
          ),
        ],
      ),
    );
  }
}
