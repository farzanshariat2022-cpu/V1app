import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// مدل عادت - نگاشت‌شده روی سند users/{uid}/habits/{habitId}
/// تاریخ‌های انجام‌شده مستقیماً به‌صورت یک Map روی خود سند نگه داشته می‌شود
/// (کلید: yyyy-MM-dd) تا هم برای Heat Map ساده باشد و هم نیازی به ساب‌کالکشن
/// جداگانه و کوئری‌های اضافه نباشد.
class HabitModel {
  final String id;
  final String title;
  final DateTime createdAt;
  final Map<String, bool> completedDates;

  HabitModel({
    required this.id,
    required this.title,
    required this.createdAt,
    Map<String, bool>? completedDates,
  }) : completedDates = completedDates ?? {};

  factory HabitModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    final rawDates = map['completedDates'] as Map<String, dynamic>? ?? {};
    return HabitModel(
      id: doc.id,
      title: map['title'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedDates: rawDates.map((k, v) => MapEntry(k, v == true)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedDates': completedDates,
    };
  }

  bool isCompletedOn(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return completedDates[key] == true;
  }

  bool get isCompletedToday => isCompletedOn(DateTime.now());

  /// تعداد روزهای پشت‌سرهم انجام‌شده. اگر امروز هنوز ثبت نشده، شمارش از دیروز
  /// شروع می‌شود (چون امروز هنوز تمام نشده)؛ به‌محض جاافتادن یک روز، صفر می‌شود.
  int get currentStreak {
    int streak = 0;
    DateTime cursor = DateTime.now();
    if (!isCompletedOn(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (isCompletedOn(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// درصد موفقیت: تعداد روزهای انجام‌شده از روز ساخت عادت تا امروز
  double get successRatePercent {
    final totalDays = DateTime.now().difference(createdAt).inDays + 1;
    if (totalDays <= 0) return 0;
    final doneDays = completedDates.values.where((v) => v).length;
    return (doneDays / totalDays) * 100;
  }

  /// آیا دیروز، پریروز و پس‌پریروز (۳ روز کامل قبل از امروز) همه جا افتاده‌اند؟
  /// معیار هشدار شکست عادت طبق بخش ۴ پرامپت.
  bool get failedLast3Days {
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
    if (createdAt.isAfter(threeDaysAgo)) return false; // عادت به‌اندازه‌ی کافی قدیمی نیست

    for (int i = 1; i <= 3; i++) {
      final day = DateTime.now().subtract(Duration(days: i));
      if (isCompletedOn(day)) return false;
    }
    return true;
  }

  /// دیتاست مناسب برای ویجت flutter_heatmap_calendar: Map<DateTime, int>
  Map<DateTime, int> get heatmapDatasets {
    final result = <DateTime, int>{};
    completedDates.forEach((key, done) {
      if (!done) return;
      try {
        final d = DateFormat('yyyy-MM-dd').parse(key);
        result[DateTime(d.year, d.month, d.day)] = 1;
      } catch (_) {
        // کلید نامعتبر را نادیده می‌گیریم
      }
    });
    return result;
  }
}
