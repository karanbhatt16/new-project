import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/app_user.dart';
import '../auth/firebase_auth_controller.dart';
import '../chat/firestore_chat_controller.dart';
import '../social/firestore_social_graph_controller.dart';

/// Dialog for sharing a game to friends via in-app chat (like Instagram).
/// 
/// Shows a list of friends and allows selecting multiple recipients.
class ShareGameDialog extends StatefulWidget {
  const ShareGameDialog({
    super.key,
    required this.currentUserUid,
    required this.currentUserEmail,
    required this.auth,
    required this.social,
    required this.chat,
    required this.gameTitle,
    required this.gameEmoji,
    required this.shareMessage,
  });

  final String currentUserUid;
  final String currentUserEmail;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;
  final FirestoreChatController chat;
  final String gameTitle;
  final String gameEmoji;
  final String shareMessage;

  /// Shows the share dialog and returns true if message was sent successfully.
  static Future<bool> show({
    required BuildContext context,
    required String currentUserUid,
    required String currentUserEmail,
    required FirebaseAuthController auth,
    required FirestoreSocialGraphController social,
    required FirestoreChatController chat,
    required String gameTitle,
    required String gameEmoji,
    required String shareMessage,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareGameDialog(
        currentUserUid: currentUserUid,
        currentUserEmail: currentUserEmail,
        auth: auth,
        social: social,
        chat: chat,
        gameTitle: gameTitle,
        gameEmoji: gameEmoji,
        shareMessage: shareMessage,
      ),
    );
    return result ?? false;
  }

  @override
  State<ShareGameDialog> createState() => _ShareGameDialogState();
}

class _ShareGameDialogState extends State<ShareGameDialog> {
  List<AppUser>? _friends;
  bool _loading = true;
  String? _error;
  final Set<String> _selectedUids = {};
  bool _sending = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final friendUids = await widget.social.getFriends(uid: widget.currentUserUid);
      final friends = <AppUser>[];
      
      for (final uid in friendUids) {
        final user = await widget.auth.publicProfileByUid(uid);
        if (user != null) {
          friends.add(user);
        }
      }
      
      // Sort alphabetically
      friends.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
      
      if (mounted) {
        setState(() {
          _friends = friends;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<AppUser> get _filteredFriends {
    if (_friends == null) return [];
    if (_searchQuery.isEmpty) return _friends!;
    
    final query = _searchQuery.toLowerCase();
    return _friends!.where((f) => 
      f.username.toLowerCase().contains(query)
    ).toList();
  }

  Future<void> _sendToSelected() async {
    if (_selectedUids.isEmpty || _sending) return;
    
    setState(() => _sending = true);
    HapticFeedback.mediumImpact();
    
    try {
      int successCount = 0;
      
      for (final uid in _selectedUids) {
        final friend = _friends!.firstWhere((f) => f.uid == uid);
        
        // Get or create thread
        final thread = await widget.chat.getOrCreateThread(
          myUid: widget.currentUserUid,
          myEmail: widget.currentUserEmail,
          otherUid: friend.uid,
          otherEmail: friend.email,
        );
        
        // Send the share message
        await widget.chat.sendMessagePlaintext(
          threadId: thread.id,
          fromUid: widget.currentUserUid,
          fromEmail: widget.currentUserEmail,
          toUid: friend.uid,
          toEmail: friend.email,
          text: widget.shareMessage,
        );
        
        successCount++;
      }
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to $successCount ${successCount == 1 ? 'friend' : 'friends'}! 🎮'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  widget.gameEmoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share ${widget.gameTitle}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Send to friends via chat',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Send button
                FilledButton.icon(
                  onPressed: _selectedUids.isEmpty || _sending ? null : _sendToSelected,
                  icon: _sending 
                      ? const SizedBox(
                          width: 16, 
                          height: 16, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: Text(_selectedUids.isEmpty ? 'Send' : 'Send (${_selectedUids.length})'),
                ),
              ],
            ),
          ),
          
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Friends list
          Expanded(
            child: _buildContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load friends', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_error!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    
    if (_friends == null || _friends!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😢', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                'No friends yet',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Add some friends to share games with them!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    final filtered = _filteredFriends;
    
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'No friends match "$_searchQuery"',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final friend = filtered[index];
        final isSelected = _selectedUids.contains(friend.uid);
        
        return _FriendTile(
          friend: friend,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                _selectedUids.remove(friend.uid);
              } else {
                _selectedUids.add(friend.uid);
              }
            });
          },
          theme: theme,
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  final AppUser friend;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: friend.profileImageBytes != null
                ? MemoryImage(Uint8List.fromList(friend.profileImageBytes!))
                : null,
            child: friend.profileImageBytes == null
                ? Text(
                    friend.username.isEmpty ? '?' : friend.username[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  )
                : null,
          ),
          if (isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.surface, width: 2),
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
      title: Text(
        friend.username,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: friend.bio.isNotEmpty
          ? Text(
              friend.bio,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primary 
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary 
                : theme.colorScheme.outline,
            width: 2,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
