import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../posts/firestore_posts_controller.dart';
import '../../posts/post_models.dart';
import '../widgets/async_action.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.currentUid,
    required this.posts,
  });

  final Post post;
  final String currentUid;
  final FirestorePostsController posts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1,
                child: FutureBuilder<String>(
                  future: FirebaseStorage.instance.ref(post.imagePath).getDownloadURL(),
                  builder: (context, snap) {
                    final url = snap.data;
                    if (url == null) {
                      return Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }
                    return Image.network(url, fit: BoxFit.cover);
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (post.caption.isNotEmpty) Text(post.caption),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Reports: ${post.reportCount}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Report',
                  onPressed: () => _showReportDialog(context),
                  icon: const Icon(Icons.flag_outlined),
                ),
                if (post.createdByUid == currentUid)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => runAsyncAction(
                      context,
                      () => posts.deletePost(postId: post.id, requesterUid: currentUid),
                    ),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final reasons = <String>['HARASSMENT', 'NUDITY', 'OTHER'];
    String selected = reasons.first;
    final details = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selected,
                items: [for (final r in reasons) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => selected = v ?? reasons.first,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: details,
                decoration: const InputDecoration(labelText: 'Details (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                fireAndForget(
                  runAsyncAction(
                    context,
                    () => posts.reportPost(
                      postId: post.id,
                      reportedByUid: currentUid,
                      reason: selected,
                      details: details.text.trim().isEmpty ? null : details.text.trim(),
                    ),
                    successMessage: 'Reported',
                  ),
                );
              },
              child: const Text('Report'),
            ),
          ],
        );
      },
    ).whenComplete(details.dispose);
  }
}
