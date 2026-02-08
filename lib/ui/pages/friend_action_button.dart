import 'dart:async';

import 'package:flutter/material.dart';

/// Optimistic state for friend actions
enum _OptimisticFriendState {
  none,
  sending,    // Optimistically showing "Request sent"
  accepting,  // Optimistically showing "Friends"
}

/// Small helper widget for consistent friend/request button states.
/// Now with optimistic updates - UI changes instantly before server confirms.
class FriendActionButton extends StatefulWidget {
  const FriendActionButton({
    super.key,
    required this.areFriends,
    required this.hasOutgoing,
    required this.hasIncoming,
    required this.onAdd,
    required this.onAccept,
    this.onBlock,
    this.dense = false,
  });

  final bool areFriends;
  final bool hasOutgoing;
  final bool hasIncoming;
  final Future<void> Function() onAdd;
  final Future<void> Function() onAccept;
  final Future<void> Function()? onBlock;
  final bool dense;

  @override
  State<FriendActionButton> createState() => _FriendActionButtonState();
}

class _FriendActionButtonState extends State<FriendActionButton> {
  _OptimisticFriendState _optimisticState = _OptimisticFriendState.none;
  bool _isLoading = false;

  // Effective states (combining server state with optimistic state)
  bool get _effectiveAreFriends {
    if (_optimisticState == _OptimisticFriendState.accepting) return true;
    return widget.areFriends;
  }

  bool get _effectiveHasOutgoing {
    if (_optimisticState == _OptimisticFriendState.sending) return true;
    if (_optimisticState == _OptimisticFriendState.accepting) return false;
    return widget.hasOutgoing;
  }

  bool get _effectiveHasIncoming {
    if (_optimisticState == _OptimisticFriendState.accepting) return false;
    return widget.hasIncoming;
  }

  Future<void> _handleAdd() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _optimisticState = _OptimisticFriendState.sending;
    });

    try {
      // Fire and forget - don't wait for completion to show UI
      widget.onAdd().catchError((e) {
        // Revert on error
        if (mounted) {
          setState(() => _optimisticState = _OptimisticFriendState.none);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send request: $e')),
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
      _optimisticState = _OptimisticFriendState.accepting;
    });

    try {
      widget.onAccept().catchError((e) {
        // Revert on error
        if (mounted) {
          setState(() => _optimisticState = _OptimisticFriendState.none);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to accept request: $e')),
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
  void didUpdateWidget(FriendActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear optimistic state when server state catches up
    if (widget.areFriends != oldWidget.areFriends ||
        widget.hasOutgoing != oldWidget.hasOutgoing ||
        widget.hasIncoming != oldWidget.hasIncoming) {
      _optimisticState = _OptimisticFriendState.none;
    }
  }

  Future<void> _handleBlock(BuildContext context) async {
    if (_isLoading || widget.onBlock == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User?'),
        content: const Text('Are you sure you want to block this user? They will not be able to chat with you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await widget.onBlock!();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to block user: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_effectiveAreFriends) {
      if (widget.onBlock != null) {
        return FilledButton.tonalIcon(
          onPressed: _isLoading ? null : () => _handleBlock(context),
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.block),
          label: Text(widget.dense ? 'Block' : 'Block user'),
        );
      }
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.check),
        label: Text(widget.dense ? 'Friends' : 'Already friends'),
      );
    }

    if (_effectiveHasIncoming) {
      return FilledButton.icon(
        onPressed: _isLoading ? null : _handleAccept,
        icon: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.person_add_alt_1),
        label: Text(widget.dense ? 'Accept' : 'Accept request'),
      );
    }

    if (_effectiveHasOutgoing) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top),
        label: Text(widget.dense ? 'Requested' : 'Request sent'),
      );
    }

    return FilledButton.icon(
      onPressed: _isLoading ? null : _handleAdd,
      icon: _isLoading 
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.person_add),
      label: Text(widget.dense ? 'Add' : 'Add friend'),
    );
  }
}
