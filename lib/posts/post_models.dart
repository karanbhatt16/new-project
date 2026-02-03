import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Post {
  const Post({
    required this.id,
    required this.createdByUid,
    required this.caption,
    required this.imagePath,
    required this.createdAt,
    required this.status,
    required this.reportCount,
  });

  final String id;
  final String createdByUid;
  final String caption;
  final String imagePath;
  final DateTime createdAt;
  final String status;
  final int reportCount;

  static Post fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Post(
      id: doc.id,
      createdByUid: d['createdByUid'] as String,
      caption: (d['caption'] as String?) ?? '',
      imagePath: d['imagePath'] as String,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: (d['status'] as String?) ?? 'PUBLISHED',
      reportCount: (d['reportCount'] as int?) ?? 0,
    );
  }
}
