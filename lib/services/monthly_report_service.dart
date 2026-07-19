import '../models/daily_log_model.dart';
import '../models/monthly_report_model.dart';
import 'firestore_service.dart';
import 'gemini_service.dart';

/// معادل سمت‌کلاینت Cloud Function `generateMonthlyReport` از بخش ۶ پرامپت.
/// الگوی خلق‌وخو، روزهای اوج/حضیض، بیشترین علت اهمال‌کاری، و پیشنهاد برای
/// ماه بعد را از روی داده‌های واقعی همان ماه می‌سازد.
class MonthlyReportService {
  final FirestoreService _firestore = FirestoreService();
  final GeminiService _gemini = GeminiService();

  Future<MonthlyReportModel> generateReport(String uid, String yyyyMM, {String? geminiApiKey}) async {
    final logs = await _firestore.getLogsForMonth(uid, yyyyMM);

    if (logs.isEmpty) {
      final empty = MonthlyReportModel(
        month: yyyyMM,
        summaryText: 'برای این ماه هنوز داده‌ای ثبت نشده تا تحلیلی ساخته شود.',
        generatedAt: DateTime.now(),
      );
      await _firestore.saveMonthlyReport(uid, empty);
      return empty;
    }

    final analysis = _analyze(logs);
    final templateText = _buildTemplateText(analysis);

    String finalText = templateText;
    bool aiGenerated = false;

    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      final aiText = await _gemini.generateText(
        apiKey: geminiApiKey,
        prompt: _buildPrompt(analysis),
      );
      if (aiText != null && aiText.isNotEmpty) {
        finalText = aiText;
        aiGenerated = true;
      }
    }

    final report = MonthlyReportModel(
      month: yyyyMM,
      summaryText: finalText,
      generatedAt: DateTime.now(),
      isAiGenerated: aiGenerated,
    );
    await _firestore.saveMonthlyReport(uid, report);
    return report;
  }

  _MonthAnalysis _analyze(List<DailyLogModel> logs) {
    final withMood = logs.where((l) => l.moodScore != null).toList();
    final avgMood = withMood.isEmpty
        ? null
        : withMood.map((l) => l.moodScore!).reduce((a, b) => a + b) / withMood.length;

    DailyLogModel? bestDay;
    DailyLogModel? worstDay;
    for (final log in withMood) {
      if (bestDay == null || log.moodScore! > bestDay.moodScore!) bestDay = log;
      if (worstDay == null || log.moodScore! < worstDay.moodScore!) worstDay = log;
    }

    final totalStudy = logs.fold<int>(0, (a, l) => a + l.studyMinutes);
    final totalWorkout = logs.fold<int>(0, (a, l) => a + l.workoutMinutes);
    final totalInstagram = logs.fold<int>(0, (a, l) => a + l.instagramMinutes);
    final avgStudy = totalStudy / logs.length;

    // همبستگی ساده: روزهایی که اینستاگرام بالای میانگین بود ولی مطالعه پایین میانگین بود
    final avgInstagram = totalInstagram / logs.length;
    final procrastinationDays = logs
        .where((l) => l.instagramMinutes > avgInstagram && l.studyMinutes < avgStudy)
        .length;
    final procrastinationRate = procrastinationDays / logs.length;

    return _MonthAnalysis(
      totalDays: logs.length,
      avgMood: avgMood,
      bestDay: bestDay,
      worstDay: worstDay,
      totalStudyMinutes: totalStudy,
      totalWorkoutMinutes: totalWorkout,
      avgStudyMinutesPerDay: avgStudy,
      procrastinationRate: procrastinationRate,
    );
  }

  String _buildPrompt(_MonthAnalysis a) {
    return '''
تو دستیار تحلیل شخصیت «فرزان» هستی، دانشجوی دامپزشکی ۲۲ ساله (ENTP).
داده‌های یک ماه اخیرش:
- تعداد روزهای ثبت‌شده: ${a.totalDays}
- میانگین خلق‌وخو: ${a.avgMood?.toStringAsFixed(1) ?? 'نامشخص'} از ۱۰
- مجموع مطالعه: ${a.totalStudyMinutes} دقیقه (میانگین روزانه ${a.avgStudyMinutesPerDay.toStringAsFixed(0)} دقیقه)
- مجموع ورزش: ${a.totalWorkoutMinutes} دقیقه
- در ${(a.procrastinationRate * 100).toStringAsFixed(0)}٪ روزها، اینستاگرام بالا و مطالعه پایین بوده (نشونه‌ی اهمال‌کاری با محرک گوشی)

یک گزارش شخصیتی کوتاه (حداکثر ۶ جمله) به فارسی بنویس: الگوی کلی خلق‌وخو،
بزرگ‌ترین عامل اهمال‌کاری، و ۲ پیشنهاد مشخص برای ماه بعد. لحن مستقیم و
تحلیلی، نه نصیحت‌گونه‌ی کلی.
''';
  }

  String _buildTemplateText(_MonthAnalysis a) {
    final buffer = StringBuffer();
    buffer.write('این ماه ${a.totalDays} روز داده ثبت کردی. ');

    if (a.avgMood != null) {
      buffer.write('میانگین خلق‌وخوت ${a.avgMood!.toStringAsFixed(1)} از ۱۰ بود. ');
    }

    buffer.write('در مجموع ${a.totalStudyMinutes} دقیقه مطالعه و ${a.totalWorkoutMinutes} '
        'دقیقه ورزش داشتی (میانگین روزانه‌ی مطالعه: ${a.avgStudyMinutesPerDay.toStringAsFixed(0)} دقیقه). ');

    if (a.procrastinationRate > 0.3) {
      buffer.write(
        'در حدود ${(a.procrastinationRate * 100).toStringAsFixed(0)}٪ روزها، بالارفتن اینستاگرام '
        'با افت مطالعه همزمان بوده — این محتمل‌ترین عامل اهمال‌کاریته. ماه بعد رو محدودیت '
        'زمانی روی اینستاگرام بذار، مخصوصاً صبح‌ها.',
      );
    } else {
      buffer.write('الگوی مشخصی از اهمال‌کاری مرتبط با گوشی دیده نشد — ادامه بده.');
    }

    return buffer.toString();
  }
}

class _MonthAnalysis {
  final int totalDays;
  final double? avgMood;
  final DailyLogModel? bestDay;
  final DailyLogModel? worstDay;
  final int totalStudyMinutes;
  final int totalWorkoutMinutes;
  final double avgStudyMinutesPerDay;
  final double procrastinationRate;

  _MonthAnalysis({
    required this.totalDays,
    required this.avgMood,
    required this.bestDay,
    required this.worstDay,
    required this.totalStudyMinutes,
    required this.totalWorkoutMinutes,
    required this.avgStudyMinutesPerDay,
    required this.procrastinationRate,
  });
}
