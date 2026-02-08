import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';
import '../widgets/async_error_view.dart';
import 'user_profile_page.dart';

/// Page showing a user's match history (current and past matches).
/// This is PUBLIC - anyone can view anyone's match history.
class MatchHistoryPage extends StatelessWidget {
  const MatchHistoryPage({
    super.key,
    required this.profileUid,
    required this.profileUsername,
    required this.currentUserUid,
    required this.auth,
    required this.social,
    this.isOwnProfile = false,
  });

  final String profileUid;
  final String profileUsername;
  final String currentUserUid;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwnProfile ? 'My Match History' : "$profileUsername's Matches"),
      ),
      body: StreamBuilder<List<Match>>(
        stream: social.matchHistoryStream(uid: profileUid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AsyncErrorView(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final matches = snapshot.data!;
          if (matches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isOwnProfile ? 'No matches yet' : '$profileUsername has no matches yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isOwnProfile) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Start swiping to find your match!',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          // Separate current match from past matches
          final currentMatch = matches.where((m) => m.isActive).toList();
          final pastMatches = matches.where((m) => m.isBroken).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Current Match Section
              if (currentMatch.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  icon: Icons.favorite,
                  title: 'Current Relationship',
                  color: Colors.pink,
                ),
                const SizedBox(height: 12),
                _CurrentMatchCard(
                  match: currentMatch.first,
                  profileUid: profileUid,
                  currentUserUid: currentUserUid,
                  auth: auth,
                  social: social,
                  isOwnProfile: isOwnProfile,
                ),
                const SizedBox(height: 24),
              ],

              // Past Matches Section
              if (pastMatches.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  icon: Icons.history,
                  title: 'Past Relationships',
                  subtitle: '${pastMatches.length} previous match${pastMatches.length > 1 ? 'es' : ''}',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                for (final match in pastMatches) ...[
                  _PastMatchCard(
                    match: match,
                    profileUid: profileUid,
                    currentUserUid: currentUserUid,
                    auth: auth,
                    social: social,
                  ),
                  const SizedBox(height: 8),
                ],
              ],

              // Empty state for past matches when there's only current
              if (currentMatch.isNotEmpty && pastMatches.isEmpty) ...[
                _buildSectionHeader(
                  context,
                  icon: Icons.history,
                  title: 'Past Relationships',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOwnProfile
                        ? 'This is your first relationship! 🎉'
                        : 'This is their first relationship!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrentMatchCard extends StatelessWidget {
  const _CurrentMatchCard({
    required this.match,
    required this.profileUid,
    required this.currentUserUid,
    required this.auth,
    required this.social,
    required this.isOwnProfile,
  });

  final Match match;
  final String profileUid;
  final String currentUserUid;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partnerUid = match.otherUid(profileUid);

    return FutureBuilder<AppUser?>(
      future: auth.publicProfileByUid(partnerUid),
      builder: (context, snapshot) {
        final partner = snapshot.data;
        final partnerName = partner?.username ?? 'Loading...';

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.pink.shade50,
                Colors.red.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.pink.shade200),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.pink.shade100,
                  backgroundImage: partner?.profileImageBytes != null
                      ? MemoryImage(Uint8List.fromList(partner!.profileImageBytes!))
                      : null,
                  child: partner?.profileImageBytes == null
                      ? Icon(Icons.person, color: Colors.pink.shade400)
                      : null,
                ),
                title: Text(
                  partnerName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: match.matchedAt != null
                    ? Text(
                        'Together since ${DateFormat.yMMMd().format(match.matchedAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.pink.shade700,
                        ),
                      )
                    : null,
                trailing: const Icon(Icons.favorite, color: Colors.pink, size: 28),
                onTap: partner != null
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserProfilePage(
                              currentUserUid: currentUserUid,
                              user: partner,
                              social: social,
                              auth: auth,
                            ),
                          ),
                        )
                    : null,
              ),
              if (isOwnProfile) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmBreakUp(context, partnerName),
                    icon: const Icon(Icons.heart_broken),
                    label: const Text('Break Up'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmBreakUp(BuildContext context, String partnerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Break Up?'),
        content: Text(
          'Are you sure you want to break up with $partnerName? '
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

    if (confirmed == true && context.mounted) {
      await runAsyncAction(
        context,
        () => social.breakMatch(uid: currentUserUid),
        successMessage: 'Relationship ended',
      );
    }
  }
}

class _PastMatchCard extends StatelessWidget {
  const _PastMatchCard({
    required this.match,
    required this.profileUid,
    required this.currentUserUid,
    required this.auth,
    required this.social,
  });

  final Match match;
  final String profileUid;
  final String currentUserUid;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partnerUid = match.otherUid(profileUid);

    return FutureBuilder<AppUser?>(
      future: auth.publicProfileByUid(partnerUid),
      builder: (context, snapshot) {
        final partner = snapshot.data;
        final partnerName = partner?.username ?? 'Unknown';

        // Calculate relationship duration
        String durationText = '';
        if (match.matchedAt != null && match.brokenAt != null) {
          final duration = match.brokenAt!.difference(match.matchedAt!);
          if (duration.inDays > 365) {
            final years = (duration.inDays / 365).floor();
            durationText = '$years year${years > 1 ? 's' : ''}';
          } else if (duration.inDays > 30) {
            final months = (duration.inDays / 30).floor();
            durationText = '$months month${months > 1 ? 's' : ''}';
          } else if (duration.inDays > 0) {
            durationText = '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
          } else {
            durationText = 'Less than a day';
          }
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: partner?.profileImageBytes != null
                  ? MemoryImage(Uint8List.fromList(partner!.profileImageBytes!))
                  : null,
              child: partner?.profileImageBytes == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              partnerName,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (match.matchedAt != null && match.brokenAt != null)
                  Text(
                    '${DateFormat.yMMMd().format(match.matchedAt!)} - ${DateFormat.yMMMd().format(match.brokenAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (durationText.isNotEmpty)
                  Text(
                    durationText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            trailing: Icon(
              Icons.heart_broken,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: 20,
            ),
            onTap: partner != null
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfilePage(
                          currentUserUid: currentUserUid,
                          user: partner,
                          social: social,
                          auth: auth,
                        ),
                      ),
                    )
                : null,
          ),
        );
      },
    );
  }
}
