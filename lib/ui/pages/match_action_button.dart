import 'dart:async';

import 'package:flutter/material.dart';

import '../../social/firestore_social_graph_controller.dart';

/// Optimistic state for match actions
enum _OptimisticMatchState {
  none,
  sendingRequest,  // Optimistically showing "Request sent"
  accepting,       // Optimistically showing "Matched"
  breakingUp,      // Optimistically showing available state
}

/// Widget for consistent match action button states.
/// Shows different states based on match relationship between users.
/// Now with optimistic updates - UI changes instantly before server confirms.
class MatchActionButton extends StatefulWidget {
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
  State<MatchActionButton> createState() => _MatchActionButtonState();
}

class _MatchActionButtonState extends State<MatchActionButton> {
  _OptimisticMatchState _optimisticState = _OptimisticMatchState.none;
  bool _isLoading = false;

  // Effective states (combining server state with optimistic state)
  bool get _effectiveAreMatched {
    if (_optimisticState == _OptimisticMatchState.accepting) return true;
    if (_optimisticState == _OptimisticMatchState.breakingUp) return false;
    return widget.status.areMatched;
  }

  bool get _effectiveHasOutgoing {
    if (_optimisticState == _OptimisticMatchState.sendingRequest) return true;
    if (_optimisticState == _OptimisticMatchState.accepting) return false;
    return widget.status.hasOutgoingRequest;
  }

  bool get _effectiveHasIncoming {
    if (_optimisticState == _OptimisticMatchState.accepting) return false;
    return widget.status.hasIncomingRequest;
  }

  Future<void> _handleSendRequest() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _optimisticState = _OptimisticMatchState.sendingRequest;
    });

    try {
      widget.onSendRequest().catchError((e) {
        if (mounted) {
          setState(() => _optimisticState = _OptimisticMatchState.none);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send match request: $e')),
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAccept() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _optimisticState = _OptimisticMatchState.accepting;
    });

    try {
      widget.onAcceptRequest().catchError((e) {
        if (mounted) {
          setState(() => _optimisticState = _OptimisticMatchState.none);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to accept match: $e')),
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleBreakUp() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _optimisticState = _OptimisticMatchState.breakingUp;
    });

    try {
      widget.onBreakUp().catchError((e) {
        if (mounted) {
          setState(() => _optimisticState = _OptimisticMatchState.none);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to break up: $e')),
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void didUpdateWidget(MatchActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear optimistic state when server state catches up
    if (widget.status.areMatched != oldWidget.status.areMatched ||
        widget.status.hasOutgoingRequest != oldWidget.status.hasOutgoingRequest ||
        widget.status.hasIncomingRequest != oldWidget.status.hasIncomingRequest) {
      _optimisticState = _OptimisticMatchState.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Already matched with this person
    if (_effectiveAreMatched) {
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
                  widget.dense ? 'Matched ❤️' : 'In a relationship ❤️',
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
            onPressed: _isLoading ? null : () => _confirmBreakUp(context),
            icon: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.heart_broken),
            label: const Text('Break Up'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      );
    }

    // I have an incoming match request from this person
    if (_effectiveHasIncoming) {
      return FilledButton.icon(
        onPressed: _isLoading ? null : _handleAccept,
        icon: _isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.favorite_border),
        label: Text(widget.dense ? 'Accept' : 'Accept Match Request'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.pink,
        ),
      );
    }

    // I sent a match request to this person (pending)
    if (_effectiveHasOutgoing) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top),
        label: Text(widget.dense ? 'Pending' : 'Match Request Sent'),
      );
    }

    // I'm already matched with someone else
    if (widget.status.iAmAlreadyMatched) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.block),
        label: Text(widget.dense ? 'You\'re taken' : 'You\'re already in a relationship'),
      );
    }

    // They're already matched with someone else
    if (widget.status.theyAreAlreadyMatched) {
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
                    widget.theirPartnerUsername != null
                        ? '${widget.otherUsername ?? 'This user'} is currently matched with ${widget.theirPartnerUsername}'
                        : '${widget.otherUsername ?? 'This user'} is already in a relationship',
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
      onPressed: _isLoading ? null : _handleSendRequest,
      icon: _isLoading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.favorite_border),
      label: Text(widget.dense ? 'Match' : 'Send Match Request'),
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
          'Are you sure you want to break up with ${widget.otherUsername ?? 'your match'}? '
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
      await _handleBreakUp();
    }
  }
}
