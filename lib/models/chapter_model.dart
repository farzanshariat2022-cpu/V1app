import 'package:cloud_firestore/cloud_firestore.dart';

/// مدل فصل - نگاشت‌شده روی سند users/{uid}/chapters/{chapterId}
/// مثال: «فصل ۱: عضلات» زیر درس «آناتومی».
class ChapterModel {
  final String id;
  final String courseId;
  final String title;
  final int order;
  final DateTime createdAt;

  ChapterModel({
    required this.id,
    required this.courseId,
    required this.title,
    this.order = 0,
    required this.createdAt,
  });

  factory ChapterModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return ChapterModel(
      id: doc.id,
      courseId: map['courseId'] ?? '',
      title: map['title'] ?? '',
      order: map['order'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'title': title,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
