import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 20});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage:
          user.profileImageBytes == null ? null : MemoryImage(Uint8List.fromList(user.profileImageBytes!)),
      child: user.profileImageBytes == null ? const Icon(Icons.person) : null,
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
    
    final subtitle = (lastMessageText != null && lastMessageText!.isNotEmpty) 
        ? lastMessageText! 
        : 'Say hi…';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: hasUnread
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: hasUnread
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                width: 1,
              )
            : null,
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
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: hasUnread
                  ? Colors.green
                  : theme.colorScheme.primary.withValues(alpha: 0.3),
              width: hasUnread ? 2.5 : 2,
            ),
          ),
          child: UserAvatar(user: otherUser, radius: 24),
        ),
        title: Text(
          otherUser.username,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: hasUnread
                ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
        trailing: hasUnread
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unread > 99 ? '99+' : unread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
        onTap: onTap,
      ),
    );
  }
}
