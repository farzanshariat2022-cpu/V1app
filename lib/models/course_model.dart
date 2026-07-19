import 'package:cloud_firestore/cloud_firestore.dart';

/// مدل درس - نگاشت‌شده روی سند users/{uid}/courses/{courseId}
/// مثال: «آناتومی» طبق بخش ۹ پرامپت.
class CourseModel {
  final String id;
  final String title;
  final DateTime? examDate;
  final DateTime createdAt;

  CourseModel({
    required this.id,
    required this.title,
    this.examDate,
    required this.createdAt,
  });

  factory CourseModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return CourseModel(
      id: doc.id,
      title: map['title'] ?? '',
      examDate: (map['examDate'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'examDate': examDate != null ? Timestamp.fromDate(examDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  int? get daysUntilExam {
    if (examDate == null) return null;
    return examDate!.difference(DateTime.now()).inDays;
  }
}
