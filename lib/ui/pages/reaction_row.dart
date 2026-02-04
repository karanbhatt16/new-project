import 'package:flutter/material.dart';

typedef ReactionToggle = Future<void> Function(String emoji);

class ReactionRow extends StatelessWidget {
  const ReactionRow({
    super.key,
    required this.reactions,
    required this.myUid,
    required this.onToggle,
  });

  final Map<String, List<String>> reactions;
  final String myUid;
  final ReactionToggle onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final entries = reactions.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in entries)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onToggle(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: e.value.contains(myUid)
                    ? theme.colorScheme.secondary.withValues(alpha: 0.18)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text('${e.key} ${e.value.length}', style: theme.textTheme.labelLarge),
            ),
          ),
      ],
    );
  }
}
