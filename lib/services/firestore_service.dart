import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/daily_log_model.dart';
import '../models/user_model.dart';
import '../models/goal_model.dart';
import '../models/task_model.dart';
import '../models/briefing_model.dart';
import '../models/skill_model.dart';
import '../models/habit_model.dart';
import '../models/journal_entry_model.dart';
import '../models/course_model.dart';
import '../models/chapter_model.dart';
import '../models/topic_model.dart';
import '../models/chat_message_model.dart';
import '../models/memory_item_model.dart';
import '../models/monthly_report_model.dart';
import '../models/workout_log_model.dart';
import '../models/achievement_model.dart';

/// نقطه مرکزی تعامل با Firestore.
/// ساختار مجموعه‌ها دقیقا مطابق معماری کلی تعریف‌شده در پرامپت است تا
/// فازهای بعدی (اهداف، عادت‌ها، مهارت‌ها، ژورنال، ...) بدون تغییر ساختار روی
/// همین پایه سوار شوند.
///
/// users/{uid}
/// users/{uid}/daily_logs/{yyyy-MM-dd}
/// users/{uid}/goals/{goalId}          -> فاز ۲
/// users/{uid}/tasks/{taskId}          -> فاز ۲
/// users/{uid}/skills/{skillId}        -> فاز ۳
/// users/{uid}/habits/{habitId}        -> فاز ۴
/// users/{uid}/journal_entries/{id}    -> فاز ۵
/// users/{uid}/screen_time/{date}      -> فاز ۱ (نوشته می‌شود، در فازهای بعد تحلیل می‌شود)
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  CollectionReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid).collection('daily_logs');

  Future<void> saveGeminiApiKey(String uid, String apiKey) async {
    await _db.collection('users').doc(uid).set(
      {'geminiApiKey': apiKey},
      SetOptions(merge: true),
    );
  }

  /// استریم زنده‌ی سند کاربر (پروفایل)
  Stream<AppUserModel?> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AppUserModel.fromMap(uid, snap.data()!);
    });
  }

  /// استریم زنده‌ی لاگ امروز - داشبورد مستقیماً به این گوش می‌دهد
  Stream<DailyLogModel> streamTodayLog(String uid) {
    return _userDoc(uid).doc(todayKey).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return DailyLogModel.empty(todayKey);
      }
      return DailyLogModel.fromMap(todayKey, snap.data()!);
    });
  }

  /// استریم زنده‌ی لاگ‌های ۷ روز اخیر - برای نمودار هفتگی داشبورد
  Stream<List<DailyLogModel>> streamLast7DaysLogs(String uid) {
    final sevenDaysAgo = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 6)));

    return _userDoc(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: sevenDaysAgo)
        .orderBy(FieldPath.documentId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => DailyLogModel.fromMap(d.id, d.data())).toList());
  }

  /// آپدیت (merge) لاگ امروز - مثلا وقتی کاربر دقایق مطالعه را دستی وارد می‌کند
  Future<void> upsertTodayLog(String uid, Map<String, dynamic> partialData) async {
    await _userDoc(uid).doc(todayKey).set(partialData, SetOptions(merge: true));
  }

  /// ذخیره‌ی ساعتی داده اسکرین‌تایم (بخش ۱ پرامپت: users/{uid}/screen_time/{date})
  Future<void> saveScreenTimeSnapshot(
    String uid, {
    required int totalScreenTimeMinutes,
    required int instagramMinutes,
    required int youtubeMinutes,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('screen_time')
        .doc(todayKey)
        .set({
      'totalScreenTimeMinutes': totalScreenTimeMinutes,
      'instagramMinutes': instagramMinutes,
      'youtubeMinutes': youtubeMinutes,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // هم‌زمان در لاگ روزانه هم منعکس می‌شود تا داشبورد یک‌جا بخواندش
    await upsertTodayLog(uid, {
      'totalScreenTimeMinutes': totalScreenTimeMinutes,
      'instagramMinutes': instagramMinutes,
      'youtubeMinutes': youtubeMinutes,
    });
  }

  // ================== سیستم هدف (Goal Hierarchy) - فاز ۲ ==================

  CollectionReference<Map<String, dynamic>> _goalsCol(String uid) =>
      _db.collection('users').doc(uid).collection('goals');

  CollectionReference<Map<String, dynamic>> _tasksCol(String uid) =>
      _db.collection('users').doc(uid).collection('tasks');

  /// استریم زنده‌ی فرزندان مستقیم یک گره. parentId==null یعنی هدف‌های ریشه.
  /// عمداً orderBy روی سرور استفاده نمی‌شود (تا نیاز به composite index در
  /// Firestore نداشته باشیم که در یک APK نصب‌شده بدون دیباگر قابل مشاهده
  /// نیست)؛ مرتب‌سازی بر اساس order سمت کلاینت انجام می‌شود.
  Stream<List<GoalModel>> streamGoalChildren(String uid, String? parentId) {
    return _goalsCol(uid).where('parentId', isEqualTo: parentId).snapshots().map((snap) {
      final list = snap.docs.map((d) => GoalModel.fromDoc(d)).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  Future<String> addGoal(String uid, GoalModel goal) async {
    final doc = await _goalsCol(uid).add(goal.toMap());
    return doc.id;
  }

  Future<void> updateGoal(String uid, String goalId, Map<String, dynamic> data) async {
    await _goalsCol(uid).doc(goalId).update(data);
  }

  /// حذف یک گره به همراه تمام فرزندانش (بازگشتی) و تسک‌های متصل به آن‌ها
  Future<void> deleteGoalCascade(String uid, String goalId) async {
    final childrenSnap = await _goalsCol(uid).where('parentId', isEqualTo: goalId).get();
    for (final child in childrenSnap.docs) {
      await deleteGoalCascade(uid, child.id);
    }

    final tasksSnap = await _tasksCol(uid).where('goalId', isEqualTo: goalId).get();
    for (final task in tasksSnap.docs) {
      await task.reference.delete();
    }

    await _goalsCol(uid).doc(goalId).delete();
  }

  /// استریم زنده‌ی تسک‌های متصل به یک گره (معمولا یک گره از نوع «روز»).
  /// همان دلیل بالا: مرتب‌سازی سمت کلاینت به‌جای orderBy سمت سرور.
  Stream<List<TaskModel>> streamTasksForGoal(String uid, String goalId) {
    return _tasksCol(uid).where('goalId', isEqualTo: goalId).snapshots().map((snap) {
      final list = snap.docs.map((d) => TaskModel.fromDoc(d)).toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  Future<void> addTask(String uid, TaskModel task) async {
    await _tasksCol(uid).add(task.toMap());
  }

  Future<void> deleteTask(String uid, String taskId) async {
    await _tasksCol(uid).doc(taskId).delete();
  }

  /// تیک‌زدن/برداشتن تسک - در صورت تکمیل، XP مربوطه به لاگ امروز و (در صورت
  /// اتصال) به مهارت مرتبط اضافه می‌شود.
  Future<void> toggleTaskCompletion(String uid, TaskModel task) async {
    final newState = !task.isCompleted;
    await _tasksCol(uid).doc(task.id).update({'isCompleted': newState});

    if (task.xpReward > 0) {
      await upsertTodayLog(uid, {
        'xpEarned': FieldValue.increment(newState ? task.xpReward : -task.xpReward),
      });

      if (task.skillId != null) {
        await applyXpDeltaToSkill(
          uid,
          task.skillId!,
          newState ? task.xpReward : -task.xpReward,
        );
      }
    }
  }

  // ================== DailyBriefing (تحلیل سمت کلاینت) - فاز ۲ ==================

  CollectionReference<Map<String, dynamic>> _briefingsCol(String uid) =>
      _db.collection('users').doc(uid).collection('briefings');

  Stream<BriefingModel?> streamBriefing(String uid, String date) {
    return _briefingsCol(uid).doc(date).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return BriefingModel.fromMap(date, snap.data()!);
    });
  }

  Future<BriefingModel?> getBriefing(String uid, String date) async {
    final doc = await _briefingsCol(uid).doc(date).get();
    if (!doc.exists || doc.data() == null) return null;
    return BriefingModel.fromMap(date, doc.data()!);
  }

  Future<void> saveBriefing(String uid, BriefingModel briefing) async {
    await _briefingsCol(uid).doc(briefing.date).set(briefing.toMap());
  }

  /// خواندن سند لاگ یک تاریخ مشخص (غیر-استریم) - برای محاسبات تحلیل شبانه
  Future<DailyLogModel> getLogForDate(String uid, String date) async {
    final doc = await _userDoc(uid).doc(date).get();
    if (!doc.exists || doc.data() == null) return DailyLogModel.empty(date);
    return DailyLogModel.fromMap(date, doc.data()!);
  }

  /// خواندن لاگ‌های N روز گذشته قبل از یک تاریخ مشخص (غیر-استریم)
  Future<List<DailyLogModel>> getPreviousDaysLogs(String uid, String beforeDate, int days) async {
    final before = DateFormat('yyyy-MM-dd').parse(beforeDate);
    final start = DateFormat('yyyy-MM-dd').format(before.subtract(Duration(days: days)));
    final end = DateFormat('yyyy-MM-dd').format(before.subtract(const Duration(days: 1)));

    final snap = await _userDoc(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: start)
        .where(FieldPath.documentId, isLessThanOrEqualTo: end)
        .get();

    return snap.docs.map((d) => DailyLogModel.fromMap(d.id, d.data())).toList();
  }

  /// خواندن N روز اخیر شامل امروز (غیر-استریم) - برای محاسبه استریک‌های طولانی
  Future<List<DailyLogModel>> getLastNDaysLogsIncludingToday(String uid, int n) async {
    final start = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(Duration(days: n - 1)));

    final snap = await _userDoc(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: start)
        .where(FieldPath.documentId, isLessThanOrEqualTo: todayKey)
        .get();

    return snap.docs.map((d) => DailyLogModel.fromMap(d.id, d.data())).toList();
  }

  // ================== Skill Tree (XP و مهارت) - فاز ۳ ==================

  CollectionReference<Map<String, dynamic>> _skillsCol(String uid) =>
      _db.collection('users').doc(uid).collection('skills');

  Stream<List<SkillModel>> streamSkillsByCategory(String uid, SkillCategory category) {
    return _skillsCol(uid).where('category', isEqualTo: category.name).snapshots().map((snap) {
      final list = snap.docs.map((d) => SkillModel.fromDoc(d)).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  /// خواندن یک‌باره‌ی همه‌ی مهارت‌ها (برای دراپ‌داون انتخاب مهارت هنگام ساخت تسک)
  Future<List<SkillModel>> getAllSkillsOnce(String uid) async {
    final snap = await _skillsCol(uid).orderBy('name').get();
    return snap.docs.map((d) => SkillModel.fromDoc(d)).toList();
  }

  Future<void> addSkill(String uid, SkillModel skill) async {
    await _skillsCol(uid).add(skill.toMap());
  }

  Future<void> deleteSkill(String uid, String skillId) async {
    await _skillsCol(uid).doc(skillId).delete();
  }

  /// منطق لول‌آپ: وقتی XP به آستانه‌ی ۱۰۰ × لول فعلی رسید، یک لول بالا می‌رود.
  /// چون Cloud Function trigger نیاز به Blaze دارد، این محاسبه همین‌جا و در یک
  /// تراکنش (transaction) امن انجام می‌شود تا از race condition جلوگیری شود.
  /// خروجی: لولی که مهارت بعد از این تغییر در آن قرار گرفت، و اینکه لول‌آپ رخ داد یا نه.
  Future<({int newLevel, bool leveledUp})> applyXpDeltaToSkill(
    String uid,
    String skillId,
    double deltaXp,
  ) async {
    final docRef = _skillsCol(uid).doc(skillId);

    return _db.runTransaction<({int newLevel, bool leveledUp})>((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return (newLevel: 1, leveledUp: false);

      var level = (snap.data()!['level'] ?? 1) as int;
      var xp = ((snap.data()!['xp'] as num?) ?? 0).toDouble();
      final startLevel = level;

      xp += deltaXp;

      // لول‌آپ به بالا
      var threshold = 100.0 * level;
      while (xp >= threshold) {
        xp -= threshold;
        level += 1;
        threshold = 100.0 * level;
      }

      // اگر XP منفی شد (مثلا برداشتن تیک یک تسک)، تا حد امکان لول را پایین می‌آوریم
      while (xp < 0 && level > 1) {
        level -= 1;
        threshold = 100.0 * level;
        xp += threshold;
      }
      xp = xp.clamp(0, threshold);

      tx.update(docRef, {'xp': xp, 'level': level});

      return (newLevel: level, leveledUp: level > startLevel);
    });
  }

  /// ثبت یک فعالیت روی یک مهارت (مثلا «۳۰ دقیقه مطالعه» یا «۱ بازی شطرنج»).
  /// XP بر اساس xpPerUnit همان مهارت محاسبه و هم به مهارت و هم به لاگ امروز اضافه می‌شود.
  Future<({int newLevel, bool leveledUp, double xpGained})> logSkillActivity(
    String uid,
    SkillModel skill,
    double amount,
  ) async {
    final xpGained = amount * skill.xpPerUnit;
    final result = await applyXpDeltaToSkill(uid, skill.id, xpGained);
    await upsertTodayLog(uid, {'xpEarned': FieldValue.increment(xpGained)});
    return (newLevel: result.newLevel, leveledUp: result.leveledUp, xpGained: xpGained);
  }

  /// ساخت مهارت‌های پیش‌فرض برای کاربر تازه‌ثبت‌نام‌شده، دقیقا طبق لیست بخش ۳ پرامپت.
  /// دسته «روابط» عمداً خالی می‌ماند تا کاربر خودش مهارت‌های اجتماعی دلخواهش را اضافه کند.
  Future<void> seedDefaultSkills(String uid) async {
    final batch = _db.batch();
    final now = DateTime.now();

    void addDefault(String name, SkillCategory category, double rate, String unit) {
      final ref = _skillsCol(uid).doc();
      batch.set(ref, SkillModel(
        id: ref.id,
        name: name,
        category: category,
        xpPerUnit: rate,
        unitLabel: unit,
        createdAt: now,
      ).toMap());
    }

    addDefault('مطالعه', SkillCategory.knowledge, 1.0, 'دقیقه');
    addDefault('زبان', SkillCategory.knowledge, 1.0, 'دقیقه');
    addDefault('کتاب‌خوانی', SkillCategory.knowledge, 1.0, 'دقیقه');
    addDefault('پادکست', SkillCategory.knowledge, 0.25, 'دقیقه');
    addDefault('طراحی', SkillCategory.knowledge, 0.5, 'دقیقه');
    addDefault('ورزش', SkillCategory.body, 1.5, 'دقیقه');
    addDefault('شطرنج', SkillCategory.mind, 20.0, 'بازی');
    addDefault('تخته‌نرد', SkillCategory.mind, 15.0, 'بازی');
    addDefault('مدیتیشن', SkillCategory.mind, 1.5, 'دقیقه');
    addDefault('ژورنال‌نویسی', SkillCategory.mind, 10.0, 'روز');

    await batch.commit();
  }

  // ================== ردیاب عادت (Habit Tracker) - فاز ۴ ==================

  CollectionReference<Map<String, dynamic>> _habitsCol(String uid) =>
      _db.collection('users').doc(uid).collection('habits');

  Stream<List<HabitModel>> streamHabits(String uid) {
    return _habitsCol(uid)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => HabitModel.fromDoc(d)).toList());
  }

  /// خواندن یک‌باره‌ی همه‌ی عادت‌ها - برای بررسی شکست ۳ روزه در DailyBriefing
  Future<List<HabitModel>> getAllHabitsOnce(String uid) async {
    final snap = await _habitsCol(uid).orderBy('createdAt').get();
    return snap.docs.map((d) => HabitModel.fromDoc(d)).toList();
  }

  Future<void> addHabit(String uid, String title) async {
    await _habitsCol(uid).add({
      'title': title,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'completedDates': <String, bool>{},
    });
  }

  Future<void> deleteHabit(String uid, String habitId) async {
    await _habitsCol(uid).doc(habitId).delete();
  }

  /// تیک‌زدن/برداشتن یک روز مشخص برای یک عادت. از dot-notation فایراستور
  /// استفاده می‌شود تا فقط همان یک کلید داخل نقشه‌ی completedDates تغییر کند.
  Future<void> toggleHabitDate(String uid, String habitId, DateTime date, bool newValue) async {
    final key = DateFormat('yyyy-MM-dd').format(date);
    await _habitsCol(uid).doc(habitId).update({
      'completedDates.$key': newValue ? true : FieldValue.delete(),
    });
  }

  // ================== ژورنال هوشمند (Smart Journal) - فاز ۵ ==================

  CollectionReference<Map<String, dynamic>> _journalCol(String uid) =>
      _db.collection('users').doc(uid).collection('journal_entries');

  Stream<List<JournalEntryModel>> streamJournalEntries(String uid) {
    return _journalCol(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => JournalEntryModel.fromDoc(d)).toList());
  }

  Stream<JournalEntryModel?> streamJournalEntry(String uid, String entryId) {
    return _journalCol(uid).doc(entryId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return JournalEntryModel.fromDoc(snap);
    });
  }

  /// ذخیره یک نوشته ژورنال جدید. اگر امروز اولین نوشته باشد، ۱۰ XP پاداش
  /// روزانه (طبق نرخ پیش‌فرض «نوشتن ژورنال» در بخش ۳ پرامپت) به لاگ امروز
  /// اضافه و journalWritten=true می‌شود.
  Future<String> addJournalEntry(String uid, String text) async {
    final todayLog = await getLogForDate(uid, todayKey);

    final doc = await _journalCol(uid).add(
      JournalEntryModel(id: '', text: text, createdAt: DateTime.now()).toMap(),
    );

    if (!todayLog.journalWritten) {
      await upsertTodayLog(uid, {
        'journalWritten': true,
        'xpEarned': FieldValue.increment(10.0),
      });
    }

    return doc.id;
  }

  Future<void> deleteJournalEntry(String uid, String entryId) async {
    await _journalCol(uid).doc(entryId).delete();
  }

  /// ثبت نتیجه‌ی تحلیل هوش مصنوعی (یا fallback) روی یک نوشته‌ی ژورنال
  Future<void> saveJournalAnalysis(
    String uid,
    String entryId, {
    required String emotion,
    required String topic,
    required String recommendation,
  }) async {
    await _journalCol(uid).doc(entryId).update({
      'dominantEmotion': emotion,
      'mainTopic': topic,
      'recommendation': recommendation,
      'analyzed': true,
    });
  }

  // ================== تمرین ورزشی (Workout Log) - فاز ۶ ==================

  CollectionReference<Map<String, dynamic>> _workoutLogsCol(String uid) =>
      _db.collection('users').doc(uid).collection('workout_logs');

  Stream<List<WorkoutLogModel>> streamWorkoutLogs(String uid) {
    return _workoutLogsCol(uid)
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map((d) => WorkoutLogModel.fromDoc(d)).toList());
  }

  Future<void> addWorkoutLog(String uid, WorkoutLogModel log) async {
    await _workoutLogsCol(uid).add(log.toMap());
  }

  Future<void> deleteWorkoutLog(String uid, String logId) async {
    await _workoutLogsCol(uid).doc(logId).delete();
  }

  // ================== دستاوردها (Achievements) - فاز ۶ ==================

  CollectionReference<Map<String, dynamic>> _achievementsCol(String uid) =>
      _db.collection('users').doc(uid).collection('achievements');

  Stream<List<AchievementModel>> streamAchievements(String uid) {
    return _achievementsCol(uid)
        .orderBy('unlockedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AchievementModel.fromDoc(d)).toList());
  }

  /// دستاورد را فقط اگر قبلا باز نشده باشد ثبت می‌کند. خروجی true یعنی تازه باز شده.
  Future<bool> unlockAchievementIfNew(
    String uid,
    String achievementId, {
    required String title,
    required String description,
  }) async {
    final ref = _achievementsCol(uid).doc(achievementId);
    final existing = await ref.get();
    if (existing.exists) return false;

    await ref.set(AchievementModel(
      id: achievementId,
      title: title,
      description: description,
      unlockedAt: DateTime.now(),
    ).toMap());
    return true;
  }

  // ================== تسک‌های در انتظار (برای سیستم ضد اهمال‌کاری) - فاز ۶ ==================

  /// همه‌ی تسک‌های تکمیل‌نشده (حداکثر ۳۰ مورد اخیر). هم فیلتر «isCompleted»
  /// و هم مرتب‌سازی/برش سمت کلاینت انجام می‌شود تا این کوئری هرگز نیاز به
  /// composite index دستی در Firestore نداشته باشد — چون در یک APK
  /// نصب‌شده روی گوشی (بدون دیباگر متصل) کاربر اصلاً پیام خطا و لینک
  /// ساخت ایندکس را نمی‌بیند و فقط یک لیست خالی و گنگ می‌بیند.
  Stream<List<TaskModel>> streamPendingTasks(String uid) {
    return _tasksCol(uid).where('isCompleted', isEqualTo: false).snapshots().map((snap) {
      final list = snap.docs.map((d) => TaskModel.fromDoc(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(30).toList();
    });
  }

  // ================== تنبیه (Punishment cooldown) - فاز ۶ ==================

  Future<void> setLastPunishmentDate(String uid, String date) async {
    await _db.collection('users').doc(uid).set(
      {'lastPunishmentDate': date},
      SetOptions(merge: true),
    );
  }

  // ================== مدیریت درس (Course Management) - فاز ۷ ==================
  // ساختار: Course -> Chapter -> Topic (طبق بخش ۹ پرامپت)، با مجموعه‌های
  // مسطح (flat) مشابه الگوی goals/tasks تا کوئری‌ها ساده بمانند.

  CollectionReference<Map<String, dynamic>> _coursesCol(String uid) =>
      _db.collection('users').doc(uid).collection('courses');

  CollectionReference<Map<String, dynamic>> _chaptersCol(String uid) =>
      _db.collection('users').doc(uid).collection('chapters');

  CollectionReference<Map<String, dynamic>> _topicsCol(String uid) =>
      _db.collection('users').doc(uid).collection('topics');

  Stream<List<CourseModel>> streamCourses(String uid) {
    return _coursesCol(uid)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => CourseModel.fromDoc(d)).toList());
  }

  Future<String> addCourse(String uid, String title, DateTime? examDate) async {
    final doc = await _coursesCol(uid).add(
      CourseModel(id: '', title: title, examDate: examDate, createdAt: DateTime.now()).toMap(),
    );
    return doc.id;
  }

  Future<void> updateCourse(String uid, String courseId, Map<String, dynamic> data) async {
    await _coursesCol(uid).doc(courseId).update(data);
  }

  /// حذف درس به همراه تمام فصل‌ها و مبحث‌های زیرمجموعه‌اش
  Future<void> deleteCourseCascade(String uid, String courseId) async {
    final chapters = await _chaptersCol(uid).where('courseId', isEqualTo: courseId).get();
    for (final chapter in chapters.docs) {
      final topics = await _topicsCol(uid).where('chapterId', isEqualTo: chapter.id).get();
      for (final topic in topics.docs) {
        await topic.reference.delete();
      }
      await chapter.reference.delete();
    }
    await _coursesCol(uid).doc(courseId).delete();
  }

  Stream<List<ChapterModel>> streamChapters(String uid, String courseId) {
    return _chaptersCol(uid).where('courseId', isEqualTo: courseId).snapshots().map((snap) {
      final list = snap.docs.map((d) => ChapterModel.fromDoc(d)).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  Future<void> addChapter(String uid, String courseId, String title) async {
    await _chaptersCol(uid).add(
      ChapterModel(id: '', courseId: courseId, title: title, createdAt: DateTime.now()).toMap(),
    );
  }

  Future<void> deleteChapterCascade(String uid, String chapterId) async {
    final topics = await _topicsCol(uid).where('chapterId', isEqualTo: chapterId).get();
    for (final topic in topics.docs) {
      await topic.reference.delete();
    }
    await _chaptersCol(uid).doc(chapterId).delete();
  }

  Stream<List<TopicModel>> streamTopics(String uid, String chapterId) {
    return _topicsCol(uid).where('chapterId', isEqualTo: chapterId).snapshots().map((snap) {
      final list = snap.docs.map((d) => TopicModel.fromDoc(d)).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  /// خواندن یک‌باره‌ی همه‌ی مبحث‌های یک درس (برای نوار پیشرفت کلی درس)
  Future<List<TopicModel>> getTopicsForCourseOnce(String uid, String courseId) async {
    final snap = await _topicsCol(uid).where('courseId', isEqualTo: courseId).get();
    return snap.docs.map((d) => TopicModel.fromDoc(d)).toList();
  }

  /// استریم زنده‌ی همه‌ی مبحث‌های یک درس (برای نوار پیشرفت realtime)
  Stream<List<TopicModel>> streamTopicsForCourse(String uid, String courseId) {
    return _topicsCol(uid)
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TopicModel.fromDoc(d)).toList());
  }

  Future<void> addTopic(String uid, String courseId, String chapterId, String title) async {
    await _topicsCol(uid).add(
      TopicModel(
        id: '',
        courseId: courseId,
        chapterId: chapterId,
        title: title,
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  Future<void> deleteTopic(String uid, String topicId) async {
    await _topicsCol(uid).doc(topicId).delete();
  }

  /// تغییر وضعیت مبحث. اگر برای اولین بار «تکمیل‌شده» شود، طبق بخش ۹ پرامپت
  /// خودکار تسک‌های مرور علمی برای ۱، ۳، ۷، ۱۵ و ۳۰ روز بعد ساخته می‌شود.
  static const List<int> spacedRepetitionDays = [1, 3, 7, 15, 30];

  Future<void> updateTopicStatus(String uid, TopicModel topic, TopicStatus newStatus) async {
    final data = <String, dynamic>{'status': newStatus.name};

    if (newStatus == TopicStatus.completed) {
      data['completedAt'] = Timestamp.fromDate(DateTime.now());
    }

    final shouldGenerateReviews = newStatus == TopicStatus.completed && !topic.reviewsGenerated;
    if (shouldGenerateReviews) {
      data['reviewsGenerated'] = true;
    }

    await _topicsCol(uid).doc(topic.id).update(data);

    if (shouldGenerateReviews) {
      for (final days in spacedRepetitionDays) {
        final dueDate = DateTime.now().add(Duration(days: days));
        await addTask(
          uid,
          TaskModel(
            id: '',
            title: 'مرور: ${topic.title}',
            date: dueDate,
            isReview: true,
            reviewOfTopicId: topic.id,
            createdAt: DateTime.now(),
          ),
        );
      }
    }
  }

  /// تسک‌های سررسیدشده‌ی امروز یا قبل‌تر (شامل مرورهای علمی) که هنوز انجام نشده‌اند.
  /// فیلتر isCompleted عمداً سمت کلاینت انجام می‌شود تا ترکیب equality+range
  /// روی دو فیلد مختلف نیاز به composite index دستی در Firestore نداشته باشد.
  Stream<List<TaskModel>> streamTasksDueToday(String uid) {
    final endOfToday = DateTime.now().add(const Duration(days: 1));
    final boundary = DateTime(endOfToday.year, endOfToday.month, endOfToday.day);

    return _tasksCol(uid)
        .where('date', isLessThan: Timestamp.fromDate(boundary))
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TaskModel.fromDoc(d))
            .where((t) => !t.isCompleted)
            .toList());
  }

  // ================== چت هوش مصنوعی با حافظه (AI Chat) - فاز ۷ ==================

  CollectionReference<Map<String, dynamic>> _chatCol(String uid) =>
      _db.collection('users').doc(uid).collection('chat_messages');

  CollectionReference<Map<String, dynamic>> _memoryCol(String uid) =>
      _db.collection('users').doc(uid).collection('memory');

  Stream<List<ChatMessageModel>> streamChatMessages(String uid) {
    return _chatCol(uid)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessageModel.fromDoc(d)).toList());
  }

  Future<void> addChatMessage(String uid, ChatMessageModel message) async {
    await _chatCol(uid).add(message.toMap());
  }

  /// خواندن یک‌باره‌ی آخرین N پیام (برای ساخت context مکالمه برای Gemini)
  Future<List<ChatMessageModel>> getRecentChatMessagesOnce(String uid, {int limit = 12}) async {
    final snap = await _chatCol(uid).orderBy('createdAt', descending: true).limit(limit).get();
    final list = snap.docs.map((d) => ChatMessageModel.fromDoc(d)).toList();
    return list.reversed.toList();
  }

  Future<void> clearChatHistory(String uid) async {
    final snap = await _chatCol(uid).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Stream<List<MemoryItemModel>> streamMemoryItems(String uid) {
    return _memoryCol(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MemoryItemModel.fromDoc(d)).toList());
  }

  Future<List<MemoryItemModel>> getAllMemoryItemsOnce(String uid) async {
    final snap = await _memoryCol(uid).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => MemoryItemModel.fromDoc(d)).toList();
  }

  Future<void> addMemoryItem(String uid, String key, String value) async {
    await _memoryCol(uid).add(
      MemoryItemModel(id: '', key: key, value: value, createdAt: DateTime.now()).toMap(),
    );
  }

  Future<void> deleteMemoryItem(String uid, String itemId) async {
    await _memoryCol(uid).doc(itemId).delete();
  }

  // ================== گزارش شخصیت ماهانه (Monthly Report) - فاز ۷ ==================

  /// همه‌ی لاگ‌های روزانه‌ی یک ماه مشخص (فرمت ورودی: yyyy-MM)
  Future<List<DailyLogModel>> getLogsForMonth(String uid, String yyyyMM) async {
    final start = '$yyyyMM-01';
    final end = '$yyyyMM-31'; // رشته‌ای است، مقایسه‌ی لغوی برای این محدوده کافی است

    final snap = await _userDoc(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: start)
        .where(FieldPath.documentId, isLessThanOrEqualTo: end)
        .get();

    return snap.docs.map((d) => DailyLogModel.fromMap(d.id, d.data())).toList();
  }

  CollectionReference<Map<String, dynamic>> _monthlyReportsCol(String uid) =>
      _db.collection('users').doc(uid).collection('monthly_reports');

  Stream<List<MonthlyReportModel>> streamMonthlyReports(String uid) {
    return _monthlyReportsCol(uid).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => MonthlyReportModel.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.month.compareTo(a.month));
      return list;
    });
  }

  Future<void> saveMonthlyReport(String uid, MonthlyReportModel report) async {
    await _monthlyReportsCol(uid).doc(report.month).set(report.toMap());
  }
}
