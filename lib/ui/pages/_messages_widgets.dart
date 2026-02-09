import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../widgets/cached_avatar.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 20});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CachedAvatar(
      imageBytes: user.profileImageBytes,
      radius: radius,
    );
  }
}

class UserStartTile extends StatelessWidget {
  const UserStartTile({super.key, required this.user, required this.onTap});

  final AppUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: UserAvatar(user: user),
        title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.otherUser,
    required this.lastMessageText,
    required this.unread,
    required this.onTap,
  });

  final AppUser otherUser;
  final String? lastMessageText;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasUnread = unread > 0;
    
    // Debug logging
    if (hasUnread) {
      debugPrint('🔴 ConversationTile: ${otherUser.username} has $unread unread messages - DOT SHOWING');
    }
    
    final subtitle = (lastMessageText != null && lastMessageText!.isNotEmpty) 
        ? lastMessageText! 
        : 'Say hi…';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: UserAvatar(user: otherUser, radius: 24),
        title: Row(
          children: [
            // Simple dot indicator for new messages
            if (hasUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Text(
                otherUser.username,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w400,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        onTap: onTap,
      ),
    );
  }
}
