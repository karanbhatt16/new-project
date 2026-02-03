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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create post')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: _image == null
                  ? const Center(child: Text('Tap to pick an image'))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(_image!, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Caption',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              if (_image == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select an image first.')),
                );
                return;
              }

              await runAsyncAction(context, () async {
                await widget.posts.createPost(
                  createdByUid: widget.currentUid,
                  caption: _caption.text,
                  imageBytes: _image!,
                  imageExtension: _ext,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
              });
            },
            icon: const Icon(Icons.upload),
            label: const Text('Post'),
          ),
        ],
      ),
    );
  }
}
