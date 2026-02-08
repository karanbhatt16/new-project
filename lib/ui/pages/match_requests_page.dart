import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';
import 'user_profile_page.dart';

class MatchRequestsPage extends StatelessWidget {
  const MatchRequestsPage({
    super.key,
    required this.currentUid,
    required this.auth,
    required this.social,
  });

  final String currentUid;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Match requests')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Likes you', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: social.incomingMatchRequestsStream(uid: currentUid),
            builder: (context, snap) {
              final items = snap.data;
              if (items == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (items.isEmpty) {
                return Text(
                  'No incoming match requests yet.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              }

              return Column(
                children: [
                  for (final r in items)
                    FutureBuilder<AppUser?>(
                      future: auth.publicProfileByUid(r.fromUid),
                      builder: (context, userSnap) {
                        final user = userSnap.data;
                        final username = user?.username ?? r.fromUid;
                        final bio = user?.bio ?? '';
                        final interests = user?.interests ?? [];

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: user != null
                                          ? () => Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => UserProfilePage(
                                                    currentUserUid: currentUid,
                                                    user: user,
                                                    social: social,
                                                    auth: auth,
                                                  ),
                                                ),
                                              )
                                          : null,
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundImage: user?.profileImageBytes != null
                                            ? MemoryImage(Uint8List.fromList(user!.profileImageBytes!))
                                            : null,
                                        child: user?.profileImageBytes == null
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onTap: user != null
                                                ? () => Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) => UserProfilePage(
                                                          currentUserUid: currentUid,
                                                          user: user,
                                                          social: social,
                                                          auth: auth,
                                                        ),
                                                      ),
                                                    )
                                                : null,
                                            child: Text(
                                              username,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            'Wants to match',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (bio.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    bio,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (interests.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final interest in interests.take(5))
                                        Chip(
                                          label: Text(
                                            interest,
                                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                                          ),
                                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => runAsyncAction(
                                        context,
                                        () => social.declineMatchRequest(toUid: currentUid, fromUid: r.fromUid),
                                      ),
                                      child: const Text('Decline'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: () => runAsyncAction(
                                        context,
                                        () => social.acceptMatchRequest(toUid: currentUid, fromUid: r.fromUid),
                                        successMessage: 'Matched!',
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text('Your requests', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: social.outgoingMatchRequestsStream(uid: currentUid),
            builder: (context, snap) {
              final items = snap.data;
              if (items == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (items.isEmpty) {
                return Text(
                  'No outgoing requests.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              }

              return Column(
                children: [
                  for (final r in items)
                    FutureBuilder<AppUser?>(
                      future: auth.publicProfileByUid(r.toUid),
                      builder: (context, userSnap) {
                        final user = userSnap.data;
                        final username = user?.username ?? r.toUid;
                        final bio = user?.bio ?? '';
                        final interests = user?.interests ?? [];

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: user != null
                                          ? () => Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => UserProfilePage(
                                                    currentUserUid: currentUid,
                                                    user: user,
                                                    social: social,
                                                    auth: auth,
                                                  ),
                                                ),
                                              )
                                          : null,
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundImage: user?.profileImageBytes != null
                                            ? MemoryImage(Uint8List.fromList(user!.profileImageBytes!))
                                            : null,
                                        child: user?.profileImageBytes == null
                                            ? const Icon(Icons.hourglass_top)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onTap: user != null
                                                ? () => Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) => UserProfilePage(
                                                          currentUserUid: currentUid,
                                                          user: user,
                                                          social: social,
                                                          auth: auth,
                                                        ),
                                                      ),
                                                    )
                                                : null,
                                            child: Text(
                                              username,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            'Pending',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => runAsyncAction(
                                        context,
                                        () => social.cancelOutgoingMatchRequest(fromUid: currentUid, toUid: r.toUid),
                                        successMessage: 'Cancelled',
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                  ],
                                ),
                                if (bio.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    bio,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (interests.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final interest in interests.take(5))
                                        Chip(
                                          label: Text(
                                            interest,
                                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                                          ),
                                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
