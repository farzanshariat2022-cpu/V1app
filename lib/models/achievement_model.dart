import 'package:cloud_firestore/cloud_firestore.dart';

/// مدل دستاورد - نگاشت‌شده روی سند users/{uid}/achievements/{achievementId}
/// شناسه سند از قبل مشخص است (مثلا "streak_20_study") تا از تکرار جلوگیری شود.
class AchievementModel {
  final String id;
  final String title;
  final String description;
  final DateTime unlockedAt;

  AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.unlockedAt,
  });

  factory AchievementModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return AchievementModel(
      id: doc.id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      unlockedAt: (map['unlockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'unlockedAt': Timestamp.fromDate(unlockedAt),
    };
  }
}
