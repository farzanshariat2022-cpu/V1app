import 'package:cloud_firestore/cloud_firestore.dart';

/// وضعیت یک مبحث طبق بخش ۹ پرامپت
enum TopicStatus { notStarted, inProgress, completed }

extension TopicStatusLabel on TopicStatus {
  String get label {
    switch (this) {
      case TopicStatus.notStarted:
        return 'شروع‌نشده';
      case TopicStatus.inProgress:
        return 'در حال انجام';
      case TopicStatus.completed:
        return 'تکمیل‌شده';
    }
  }
}

/// مدل مبحث - نگاشت‌شده روی سند users/{uid}/topics/{topicId}
/// مثال: «عضلات دست» زیر فصل «عضلات».
class TopicModel {
  final String id;
  final String courseId;
  final String chapterId;
  final String title;
  final TopicStatus status;
  final int order;
  final DateTime? completedAt;

  /// وقتی یک بار تسک‌های مرور علمی (۱،۳،۷،۱۵،۳۰ روز بعد) برایش ساخته شد،
  /// true می‌شود تا با تغییر رفت‌وبرگشتی وضعیت، دوباره تسک تکراری نسازیم.
  final bool reviewsGenerated;
  final DateTime createdAt;

  TopicModel({
    required this.id,
    required this.courseId,
    required this.chapterId,
    required this.title,
    this.status = TopicStatus.notStarted,
    this.order = 0,
    this.completedAt,
    this.reviewsGenerated = false,
    required this.createdAt,
  });

  factory TopicModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return TopicModel(
      id: doc.id,
      courseId: map['courseId'] ?? '',
      chapterId: map['chapterId'] ?? '',
      title: map['title'] ?? '',
      status: TopicStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => TopicStatus.notStarted,
      ),
      order: map['order'] ?? 0,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      reviewsGenerated: map['reviewsGenerated'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'chapterId': chapterId,
      'title': title,
      'status': status.name,
      'order': order,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'reviewsGenerated': reviewsGenerated,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
