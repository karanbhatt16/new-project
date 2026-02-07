import 'package:flutter/material.dart';

import '../ui/app_shell.dart';
import 'app_user.dart';
import 'firebase_auth_controller.dart';
import '../ui/auth/welcome_page.dart';

import '../social/firestore_social_graph_controller.dart';

import '../chat/firestore_chat_controller.dart';
import '../notifications/firestore_notifications_controller.dart';
import '../posts/firestore_posts_controller.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.controller,
    required this.social,
    required this.chat,
    required this.notifications,
    required this.posts,
  });

  final FirebaseAuthController controller;
  final FirestoreSocialGraphController social;
  final FirestoreChatController chat;
  final FirestoreNotificationsController notifications;
  final FirestorePostsController posts;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Cache the profile future to prevent refetching on every rebuild
  Future<AppUser?>? _profileFuture;
  String? _currentUid;

  void _updateProfileFuture(String uid) {
    if (_currentUid != uid) {
      _currentUid = uid;
      _profileFuture = widget.controller.getCurrentProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final fbUser = widget.controller.firebaseUser;
        if (fbUser == null) {
          // Clear cached profile when user signs out
          _currentUid = null;
          _profileFuture = null;
          return WelcomePage(controller: widget.controller);
        }

        // Update profile future only when uid changes
        _updateProfileFuture(fbUser.uid);

        return FutureBuilder(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Failed to load profile: ${snapshot.error}'));
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final profile = snapshot.data;
            if (profile == null) {
              return const Center(child: Text('Profile not found in Firestore.'));
            }

            return AppShell(
              signedInUid: fbUser.uid,
              signedInEmail: profile.email,
              onSignOut: () => widget.controller.signOut(),
              auth: widget.controller,
              social: widget.social,
              chat: widget.chat,
              notifications: widget.notifications,
              posts: widget.posts,
            );
          },
        );
      },
    );
  }
}
