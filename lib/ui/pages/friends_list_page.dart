import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_error_view.dart';
import 'user_profile_page.dart';

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({
    super.key,
    required this.signedInUid,
    required this.auth,
    required this.social,
  });

  final String signedInUid;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search friends…',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: StreamBuilder<Set<String>>(
              stream: widget.social.friendsStream(uid: widget.signedInUid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return AsyncErrorView(error: snap.error!);
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final uids = snap.data!.toList(growable: false);
                if (uids.isEmpty) {
                  return Center(
                    child: Text(
                      'No friends yet.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  );
                }

                return FutureBuilder<List<AppUser>>(
                  future: widget.auth.publicProfilesByUids(uids),
                  builder: (context, usersSnap) {
                    if (usersSnap.hasError) {
                      return AsyncErrorView(error: usersSnap.error!);
                    }
                    if (!usersSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final q = _search.text.trim().toLowerCase();
                    var users = usersSnap.data!;
                    users.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));

                    if (q.isNotEmpty) {
                      users = users.where((u) => u.username.toLowerCase().contains(q)).toList(growable: false);
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemCount: users.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final u = users[index];
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(u.username, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => UserProfilePage(
                                currentUserUid: widget.signedInUid,
                                user: u,
                                social: widget.social,
                                auth: widget.auth,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
