import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../posts/firestore_posts_controller.dart';
import '../widgets/async_action.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    required this.currentUid,
    required this.posts,
  });

  final String currentUid;
  final FirestorePostsController posts;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _caption = TextEditingController();
  Uint8List? _image;
  String _ext = 'jpg';

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    if (f.bytes == null) return;

    final name = (f.name).toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : 'jpg';

    setState(() {
      _image = f.bytes;
      _ext = ext;
    });
  }

  void _removeImage() {
    setState(() {
      _image = null;
      _ext = 'jpg';
    });
  }

  bool get _canPost => _caption.text.trim().isNotEmpty || _image != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create post')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Text input first (like Reddit)
          TextField(
            controller: _caption,
            maxLines: 6,
            onChanged: (_) => setState(() {}), // Rebuild to update button state
            decoration: const InputDecoration(
              hintText: "What's on your mind?",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // Image section
          if (_image == null)
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add Image (optional)'),
            )
          else
            Stack(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(_image!, fit: BoxFit.cover),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    onPressed: _removeImage,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.8),
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _canPost
                ? () async {
                    await runAsyncAction(context, () async {
                      await widget.posts.createPost(
                        createdByUid: widget.currentUid,
                        caption: _caption.text,
                        imageBytes: _image,
                        imageExtension: _ext,
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    });
                  }
                : null,
            icon: const Icon(Icons.send),
            label: const Text('Post'),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some text, an image, or both!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
