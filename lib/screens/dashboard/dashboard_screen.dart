import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/daily_log_model.dart';
import '../../models/briefing_model.dart';
import '../../models/task_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/daily_analysis_service.dart';
import '../../services/gamification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../settings/settings_screen.dart';
import '../workout/workout_log_screen.dart';
import '../chat/chat_screen.dart';
import '../courses/courses_screen.dart';
import '../decision/decision_screen.dart';
import '../reports/monthly_report_screen.dart';
import 'manual_entry_form.dart';

/// داشبورد اصلی «معمار».
/// شامل آمار امروز، روند ۷ روز اخیر، و DailyBriefing واقعی که سمت کلاینت
/// (بدون Cloud Function، طبق محدودیت Spark Plan) تولید می‌شود.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _firestoreService = FirestoreService();
  final _analysisService = DailyAnalysisService();
  final _gamificationService = GamificationService();

  static const int studyGoalMinutes = 240; // ۴ ساعت هدف روزانه مطالعه (قابل تنظیم فاز بعد)
  static const int workoutGoalMinutes = 45;

  bool _briefingLoading = false;
  String? _geminiApiKey;
  bool _isInSlump = false;

  @override
  void initState() {
    super.initState();
    _autoGenerateBriefingIfNeeded();
    _runGamificationChecks();
  }

  /// اجرای بررسی‌های ضد اهمال‌کاری + Reward/Punishment (بخش‌های ۱۱ و ۱۴).
  /// چون Cloud Function نداریم، این هر بار که اپ باز می‌شود اجرا می‌شود.
  Future<void> _runGamificationChecks() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;

    try {
      final result = await _gamificationService.runDailyChecks(uid);
      if (!mounted) return;

      setState(() => _isInSlump = result.isInSlump);

      if (result.newlyUnlockedAchievementTitle != null) {
        _showCelebrationDialog(result.newlyUnlockedAchievementTitle!);
      } else if (result.punishmentMessage != null) {
        _showPunishmentDialog(result.punishmentMessage!);
      }
    } catch (_) {
      // در صورت خطا (مثلا نبود اینترنت)، بی‌صدا رد می‌شویم؛ کاربر چیزی از دست نمی‌دهد
    }
  }

  void _showCelebrationDialog(String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('🎉 دستاورد جدید!'),
        content: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('عالیه!')),
        ],
      ),
    );
  }

  void _showPunishmentDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('⚠️ هشدار'),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('باشه')),
        ],
      ),
    );
  }

  /// اگر بریفینگ امروز هنوز ساخته نشده، آن را بر پایه‌ی داده‌های دیروز می‌سازد.
  /// این معادل کلاینت‌ساید همان Cloud Function شبانه‌ی توضیح‌داده‌شده در پرامپت است.
  Future<void> _autoGenerateBriefingIfNeeded() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;

    final profile = await _firestoreService.streamUserProfile(uid).first;
    _geminiApiKey = profile?.geminiApiKey;

    setState(() => _briefingLoading = true);
    try {
      await _analysisService.ensureTodayBriefing(uid, geminiApiKey: _geminiApiKey);
    } catch (_) {
      // در صورت خطا (مثلا نبود اینترنت)، بریفینگ ساخته نمی‌شود؛ کاربر می‌تواند
      // دستی دکمه‌ی تحلیل مجدد را بزند.
    } finally {
      if (mounted) setState(() => _briefingLoading = false);
    }
  }

  Future<void> _regenerateBriefing(String uid) async {
    setState(() => _briefingLoading = true);
    try {
      await _analysisService.regenerateTodayBriefing(uid, geminiApiKey: _geminiApiKey);
    } finally {
      if (mounted) setState(() => _briefingLoading = false);
    }
  }

  void _handleMoreMenu(BuildContext context, String value) {
    switch (value) {
      case 'workout':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkoutLogScreen()));
        break;
      case 'courses':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoursesScreen()));
        break;
      case 'decision':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DecisionScreen()));
        break;
      case 'monthly_report':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MonthlyReportScreen()));
        break;
      case 'settings':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
      case 'logout':
        context.read<AuthService>().signOut();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('کاربر یافت نشد')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('امروز'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
            tooltip: 'دستیار',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            color: AppColors.surfaceLight,
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (value) => _handleMoreMenu(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'workout', child: Text('تحلیل ورزش')),
              const PopupMenuItem(value: 'courses', child: Text('درس‌ها')),
              const PopupMenuItem(value: 'decision', child: Text('کمکم کن تصمیم بگیرم')),
              const PopupMenuItem(value: 'monthly_report', child: Text('گزارش ماهانه')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'settings', child: Text('تنظیمات')),
              const PopupMenuItem(value: 'logout', child: Text('خروج')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<BriefingModel?>(
                stream: _firestoreService.streamBriefing(uid, _firestoreService.todayKey),
                builder: (context, snapshot) {
                  return _buildBriefingCard(uid, snapshot.data);
                },
              ),
              if (_isInSlump) ...[
                const SizedBox(height: 12),
                _buildSlumpBanner(),
              ],
              const SizedBox(height: 20),
              StreamBuilder<DailyLogModel>(
                stream: _firestoreService.streamTodayLog(uid),
                builder: (context, snapshot) {
                  final log = snapshot.data ?? DailyLogModel.empty(_firestoreService.todayKey);
                  return _buildStatsGrid(log);
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'روند ۷ روز اخیر',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<DailyLogModel>>(
                stream: _firestoreService.streamLast7DaysLogs(uid),
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWeeklyChart(logs),
                      const SizedBox(height: 16),
                      _buildSleepSummaryCard(logs),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildPendingTasksSection(uid),
              const SizedBox(height: 24),
              ManualEntryForm(uid: uid, firestoreService: _firestoreService),
            ],
          ),
        ),
      ),
    );
  }

  /// کارت DailyBriefing واقعی (بخش ۱ پرامپت) - تولیدشده سمت کلاینت.
  Widget _buildBriefingCard(String uid, BriefingModel? briefing) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'تحلیل امروز',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
              if (briefing?.isAiGenerated == true) ...[
                const SizedBox(width: 6),
                const Text('(Gemini)',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
              const Spacer(),
              _briefingLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
                      onPressed: () => _regenerateBriefing(uid),
                      tooltip: 'تحلیل مجدد',
                    ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            briefing?.summaryText ??
                (_briefingLoading
                    ? 'در حال تحلیل روند چند روز اخیرت...'
                    : 'هنوز داده‌ی کافی برای تحلیل نیست. چند روز لاگ کن تا تحلیل شروع شود.'),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(DailyLogModel log) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        StatCard(
          title: 'مطالعه (دقیقه)',
          value: '${log.studyMinutes}',
          icon: Icons.menu_book,
          accentColor: AppColors.primary,
          progress: log.studyMinutes / studyGoalMinutes,
        ),
        StatCard(
          title: 'ورزش (دقیقه)',
          value: '${log.workoutMinutes}',
          icon: Icons.fitness_center,
          accentColor: AppColors.success,
          progress: log.workoutMinutes / workoutGoalMinutes,
        ),
        StatCard(
          title: 'استفاده از گوشی',
          value: '${log.totalScreenTimeMinutes} دقیقه',
          icon: Icons.smartphone,
          accentColor: AppColors.danger,
        ),
        StatCard(
          title: 'XP امروز',
          value: log.xpEarned.toStringAsFixed(0),
          icon: Icons.bolt,
          accentColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(List<DailyLogModel> logs) {
    if (logs.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'هنوز داده‌ای برای این هفته ثبت نشده',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 30),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < logs.length; i++)
                  FlSpot(i.toDouble(), logs[i].studyMinutes.toDouble()),
              ],
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withOpacity(0.1),
              ),
            ),
            LineChartBarData(
              spots: [
                for (int i = 0; i < logs.length; i++)
                  FlSpot(i.toDouble(), logs[i].workoutMinutes.toDouble()),
              ],
              isCurved: true,
              color: AppColors.success,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  /// بنر هشدار دوره‌ی رکود (بخش ۱۱ پرامپت) - جایگزین کلاینت‌ساید
  /// antiProcrastinationCheck. توضیح می‌دهد چرا نمایش کارهای امروز محدود شده.
  Widget _buildSlumpBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withOpacity(0.4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'به نظر می‌رسه توی یه دوره رکودی (۳ روزه مطالعه/ورزش کمه). '
              'برنامه امروز رو سبک کردم — پایین فقط کارهای ضروری نشون داده می‌شن.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  /// خلاصه‌ی خواب هفته (بخش ۱۳ پرامپت): میانگین ساعت خواب + ساعت خواب/بیداری پیشنهادی
  Widget _buildSleepSummaryCard(List<DailyLogModel> logs) {
    final sleepLogs = logs.where((l) => l.sleepHours != null).toList();
    if (sleepLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'هنوز ساعت خوابی برای این هفته ثبت نکرده‌ای. از بخش «ثبت دستی امروز» شروع کن.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }

    final avgSleep = sleepLogs.map((l) => l.sleepHours!).reduce((a, b) => a + b) / sleepLogs.length;

    final bedTimes = logs.where((l) => l.bedTimeHour != null).map((l) => l.bedTimeHour!).toList();
    final wakeTimes = logs.where((l) => l.wakeTimeHour != null).map((l) => l.wakeTimeHour!).toList();

    String? suggestedBed;
    String? suggestedWake;
    if (bedTimes.isNotEmpty) {
      suggestedBed = _formatHour(bedTimes.reduce((a, b) => a + b) / bedTimes.length);
    }
    if (wakeTimes.isNotEmpty) {
      suggestedWake = _formatHour(wakeTimes.reduce((a, b) => a + b) / wakeTimes.length);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.bedtime_outlined, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'میانگین خواب این هفته: ${avgSleep.toStringAsFixed(1)} ساعت',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                if (suggestedBed != null && suggestedWake != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'الگوی فعلی‌ات: خواب حدود $suggestedBed، بیداری حدود $suggestedWake — '
                    'برای کیفیت بهتر خواب، این ساعت‌ها رو هر شب ثابت نگه دار.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.6),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatHour(double hour) {
    final h = hour.floor() % 24;
    final m = ((hour - hour.floor()) * 60).round();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// کارهای در انتظار (تسک‌های تکمیل‌نشده). در دوره‌ی رکود، فقط کارهای
  /// «غیر اختیاری» و حداکثر ۳ مورد نشان داده می‌شود (بخش ۱۱ پرامپت).
  Widget _buildPendingTasksSection(String uid) {
    return StreamBuilder<List<TaskModel>>(
      stream: _firestoreService.streamPendingTasks(uid),
      builder: (context, snapshot) {
        var tasks = snapshot.data ?? [];
        if (tasks.isEmpty) return const SizedBox.shrink();

        if (_isInSlump) {
          tasks = tasks.where((t) => !t.isOptional).take(3).toList();
        } else {
          tasks = tasks.take(8).toList();
        }

        if (tasks.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isInSlump ? 'فقط تمرکز کن روی این‌ها' : 'کارهای در انتظار',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...tasks.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: t.isCompleted,
                          activeColor: AppColors.primary,
                          onChanged: (_) => _firestoreService.toggleTaskCompletion(uid, t),
                        ),
                        Expanded(
                          child: Text(
                            t.title,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          ),
                        ),
                        if (t.isOptional)
                          const Text(
                            'اختیاری',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                          ),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }


}
