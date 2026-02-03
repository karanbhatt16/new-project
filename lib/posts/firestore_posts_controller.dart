import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'post_models.dart';

class FirestorePostsController {
  FirestorePostsController({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  Stream<List<Post>> postsStream({int limit = 50}) {
    return _db
        .collection('posts')
        .where('status', isEqualTo: 'PUBLISHED')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Post.fromDoc).toList(growable: false));
  }

  Future<String> createPost({
    required String createdByUid,
    required String caption,
    required Uint8List imageBytes,
    required String imageExtension,
  }) async {
    final postRef = _db.collection('posts').doc();
    final postId = postRef.id;

    final imagePath = 'posts/$postId/main.$imageExtension';

    final storageRef = _storage.ref(imagePath);
    await storageRef.putData(
      imageBytes,
      SettableMetadata(contentType: _contentTypeForExt(imageExtension)),
    );

    await postRef.set({
      'createdByUid': createdByUid,
      'caption': caption.trim(),
      'imagePath': imagePath,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'PUBLISHED',
      'reportCount': 0,
    });

    return postId;
  }

  Future<void> deletePost({required String postId, required String requesterUid}) async {
    final postRef = _db.collection('posts').doc(postId);
    final snap = await postRef.get();
    final data = snap.data();
    if (data == null) return;

    if (data['createdByUid'] != requesterUid) {
      throw StateError('Not allowed');
    }

    final imagePath = data['imagePath'] as String;

    await postRef.delete();
    await _storage.ref(imagePath).delete();
  }

  Future<void> reportPost({
    required String postId,
    required String reportedByUid,
    required String reason,
    String? details,
  }) async {
    final postRef = _db.collection('posts').doc(postId);
    final reportRef = postRef.collection('reports').doc();

    await _db.runTransaction((tx) async {
      tx.set(reportRef, {
        'reportedByUid': reportedByUid,
        'reason': reason,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(postRef, {
        'reportCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    // Auto-flag after 5 reports (can tune later).
    final updated = await postRef.get();
    final rc = (updated.data()?['reportCount'] as int?) ?? 0;
    if (rc >= 5) {
      await postRef.set({
        'status': 'AUTO_FLAGGED',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  String _contentTypeForExt(String ext) {
    final e = ext.toLowerCase();
    return switch (e) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }
}
