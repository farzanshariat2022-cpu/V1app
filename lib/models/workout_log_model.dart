import 'package:cloud_firestore/cloud_firestore.dart';

/// مدل یک لاگ تمرین ورزشی - نگاشت‌شده روی سند users/{uid}/workout_logs/{id}
/// مثال: «پرس سینه: ۳ ست ۱۰ تایی با وزنه ۲۰ کیلو»
class WorkoutLogModel {
  final String id;
  final String exerciseName;
  final int sets;
  final int reps;
  final double weightKg;
  final DateTime date;

  WorkoutLogModel({
    required this.id,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.weightKg,
    required this.date,
  });

  factory WorkoutLogModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return WorkoutLogModel(
      id: doc.id,
      exerciseName: map['exerciseName'] ?? '',
      sets: map['sets'] ?? 0,
      reps: map['reps'] ?? 0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exerciseName': exerciseName,
      'sets': sets,
      'reps': reps,
      'weightKg': weightKg,
      'date': Timestamp.fromDate(date),
    };
  }

  /// حجم تمرین این ست (برای مقایسه ساده‌ی پیشرفت): ست × تکرار × وزنه
  double get volume => sets * reps * weightKg;
}
