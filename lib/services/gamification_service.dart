import 'dart:math';
import 'package:intl/intl.dart';
import '../models/daily_log_model.dart';
import 'firestore_service.dart';

/// نتیجه‌ی یک بررسی گیمیفیکیشن که Dashboard می‌تواند برای نمایش دیالوگ/بنر استفاده کند.
class GamificationCheckResult {
  final bool isInSlump; // آیا کاربر در دوره‌ی رکود ۳ روزه است (بخش ۱۱)
  final String? newlyUnlockedAchievementTitle; // بخش ۱۴ - Reward
  final String? punishmentMessage; // بخش ۱۴ - Punishment

  GamificationCheckResult({
    required this.isInSlump,
    this.newlyUnlockedAchievementTitle,
    this.punishmentMessage,
  });
}

/// معادل سمت‌کلاینت Cloud Function `antiProcrastinationCheck` + منطق
/// Reward/Punishment از بخش‌های ۱۱ و ۱۴ پرامپت. چون روی Spark Plan نمی‌توان
/// Cloud Function زمان‌بندی‌شده (ساعت ۸ شب) داشت، این بررسی هر بار که اپ باز
/// می‌شود روی داده‌های تا این لحظه انجام می‌شود.
class GamificationService {
  final FirestoreService _firestore = FirestoreService();
  final _random = Random();

  static const int _slumpStudyThreshold = 30;
  static const int _slumpWorkoutThreshold = 10;
  static const int _studyStreakGoalDays = 20;

  /// شرط رکود: مطالعه <۳۰ دقیقه و ورزش <۱۰ دقیقه در هر سه روز اخیر (دیروز، ۲،۳ روز پیش)
  bool _isSlumpLog(DailyLogModel log) =>
      log.studyMinutes < _slumpStudyThreshold && log.workoutMinutes < _slumpWorkoutThreshold;

  Future<GamificationCheckResult> runDailyChecks(String uid) async {
    final last3 = await _firestore.getPreviousDaysLogs(
      uid,
      DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1))),
      3,
    );

    final isInSlump = last3.length == 3 && last3.every(_isSlumpLog);

    final achievementTitle = await _checkStudyStreakAchievement(uid);
    final punishmentMessage = isInSlump ? await _checkAndApplyPunishment(uid) : null;

    return GamificationCheckResult(
      isInSlump: isInSlump,
      newlyUnlockedAchievementTitle: achievementTitle,
      punishmentMessage: punishmentMessage,
    );
  }

  /// Reward (بخش ۱۴): اگر ۲۰ روز پشت‌سرهم مطالعه انجام شده باشد، دستاورد باز می‌شود.
  Future<String?> _checkStudyStreakAchievement(String uid) async {
    final logs = await _firestore.getLastNDaysLogsIncludingToday(uid, _studyStreakGoalDays);
    if (logs.length < _studyStreakGoalDays) return null;

    final allStudied = logs.every((l) => l.studyMinutes > 0);
    if (!allStudied) return null;

    const achievementId = 'streak_20_study';
    final unlocked = await _firestore.unlockAchievementIfNew(
      uid,
      achievementId,
      title: '۲۰ روز مطالعه‌ی پشت‌سرهم 🔥',
      description: 'بیست روز متوالی حداقل کمی مطالعه کرده‌ای. همینطور ادامه بده!',
    );

    return unlocked ? '۲۰ روز مطالعه‌ی پشت‌سرهم 🔥' : null;
  }

  /// Punishment (بخش ۱۴): اگر ۳ روز پشت‌سرهم به اهداف اصلی نرسیده، ۲۰٪ از XP
  /// یک مهارت تصادفی کم می‌شود. حداکثر یک‌بار هر ۳ روز اعمال می‌شود تا در طول
  /// یک دوره‌ی رکود مداوم، هر روز دوباره تنبیه نشود.
  Future<String?> _checkAndApplyPunishment(String uid) async {
    final profile = await _firestore.streamUserProfile(uid).first;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (profile?.lastPunishmentDate != null) {
      final last = DateFormat('yyyy-MM-dd').parse(profile!.lastPunishmentDate!);
      if (DateTime.now().difference(last).inDays < 3) {
        return null; // هنوز در دوره‌ی cooldown هستیم
      }
    }

    final skills = await _firestore.getAllSkillsOnce(uid);
    final skillsWithXp = skills.where((s) => s.xp > 0).toList();
    if (skillsWithXp.isEmpty) return null;

    final target = skillsWithXp[_random.nextInt(skillsWithXp.length)];
    final penalty = target.xp * 0.2;

    await _firestore.applyXpDeltaToSkill(uid, target.id, -penalty);
    await _firestore.setLastPunishmentDate(uid, today);

    return '۳ روزه به مطالعه/ورزش نرسیده‌ای، برای همین ۲۰٪ از XP «${target.name}» کم شد.';
  }
}
