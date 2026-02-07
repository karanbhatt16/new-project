import 'dart:async';

import 'package:flutter/material.dart';

import '../../social/firestore_social_graph_controller.dart';

/// Widget for consistent match action button states.
/// Shows different states based on match relationship between users.
class MatchActionButton extends StatelessWidget {
  const MatchActionButton({
    super.key,
    required this.status,
    required this.onSendRequest,
    required this.onAcceptRequest,
    required this.onBreakUp,
    this.otherUsername,
    this.theirPartnerUsername,
    this.dense = false,
  });

  final MatchStatus status;
  final Future<void> Function() onSendRequest;
  final Future<void> Function() onAcceptRequest;
  final Future<void> Function() onBreakUp;
  final String? otherUsername;
  final String? theirPartnerUsername;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Already matched with this person
    if (status.areMatched) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.pink.shade400,
                  Colors.red.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  dense ? 'Matched ❤️' : 'In a relationship ❤️',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _confirmBreakUp(context),
            icon: const Icon(Icons.heart_broken),
            label: const Text('Break Up'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      );
    }

    // I have an incoming match request from this person
    if (status.hasIncomingRequest) {
      return FilledButton.icon(
        onPressed: () async => onAcceptRequest(),
        icon: const Icon(Icons.favorite_border),
        label: Text(dense ? 'Accept' : 'Accept Match Request'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.pink,
        ),
      );
    }

    // I sent a match request to this person (pending)
    if (status.hasOutgoingRequest) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top),
        label: Text(dense ? 'Pending' : 'Match Request Sent'),
      );
    }

    // I'm already matched with someone else
    if (status.iAmAlreadyMatched) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.block),
        label: Text(dense ? 'You\'re taken' : 'You\'re already in a relationship'),
      );
    }

    // They're already matched with someone else
    if (status.theyAreAlreadyMatched) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    theirPartnerUsername != null
                        ? '${otherUsername ?? 'This user'} is currently matched with $theirPartnerUsername'
                        : '${otherUsername ?? 'This user'} is already in a relationship',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Can send a match request
    return FilledButton.icon(
      onPressed: () async => onSendRequest(),
      icon: const Icon(Icons.favorite_border),
      label: Text(dense ? 'Match' : 'Send Match Request'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.pink,
      ),
    );
  }

  Future<void> _confirmBreakUp(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Break Up?'),
        content: Text(
          'Are you sure you want to break up with ${otherUsername ?? 'your match'}? '
          'This will end your relationship and everyone will be able to see it in your match history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Break Up'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onBreakUp();
    }
  }
}
