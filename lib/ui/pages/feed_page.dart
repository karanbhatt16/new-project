import 'package:flutter/material.dart';

import '../../posts/firestore_posts_controller.dart';
import '../widgets/async_error_view.dart';
import '_post_widgets.dart';
import 'create_post_page.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({
    super.key,
    required this.currentUid,
    required this.posts,
  });

  final String currentUid;
  final FirestorePostsController posts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreatePostPage(
                currentUid: currentUid,
                posts: posts,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Post'),
      ),
      body: StreamBuilder(
        stream: posts.postsStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return AsyncErrorView(error: snap.error!);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No posts yet. Create the first one.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(
                  post: items[index],
                  currentUid: currentUid,
                  posts: posts,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
