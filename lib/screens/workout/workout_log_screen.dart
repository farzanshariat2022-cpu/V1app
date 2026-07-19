import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/workout_log_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// صفحه تحلیل ورزش (بخش ۱۳ پرامپت): کاربر ست‌های تمرینش را لاگ می‌کند
/// (مثلا «پرس سینه: ۳ ست ۱۰ تایی با ۲۰ کیلو») و روند حجم تمرین برای هر
/// حرکت به‌صورت نمودار خطی نشان داده می‌شود. اگر ۲ هفته پیشرفتی نبود، یک
/// هشدار «برنامه رو عوض کن» نمایش داده می‌شود.
class WorkoutLogScreen extends StatelessWidget {
  const WorkoutLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser!.uid;
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('تحلیل ورزش')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddLogDialog(context, uid, firestoreService),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<List<WorkoutLogModel>>(
        stream: firestoreService.streamWorkoutLogs(uid),
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'هنوز تمرینی ثبت نکرده‌ای. با دکمه + اولین ست را وارد کن\n(مثلا: پرس سینه، ۳ ست، ۱۰ تکرار، ۲۰ کیلو).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          // گروه‌بندی بر اساس اسم حرکت
          final grouped = <String, List<WorkoutLogModel>>{};
          for (final log in logs) {
            grouped.putIfAbsent(log.exerciseName, () => []).add(log);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries
                .map((e) => _ExerciseSection(
                      exerciseName: e.key,
                      logs: e.value,
                      uid: uid,
                      firestoreService: firestoreService,
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  void _showAddLogDialog(BuildContext context, String uid, FirestoreService firestoreService) {
    final nameController = TextEditingController();
    final setsController = TextEditingController(text: '3');
    final repsController = TextEditingController(text: '10');
    final weightController = TextEditingController(text: '20');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('ثبت تمرین'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'اسم حرکت (مثلا: پرس سینه)'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'ست'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: repsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'تکرار'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'وزنه (کیلو)'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              await firestoreService.addWorkoutLog(
                uid,
                WorkoutLogModel(
                  id: '',
                  exerciseName: name,
                  sets: int.tryParse(setsController.text) ?? 0,
                  reps: int.tryParse(repsController.text) ?? 0,
                  weightKg: double.tryParse(weightController.text) ?? 0,
                  date: DateTime.now(),
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}

class _ExerciseSection extends StatelessWidget {
  final String exerciseName;
  final List<WorkoutLogModel> logs;
  final String uid;
  final FirestoreService firestoreService;

  const _ExerciseSection({
    required this.exerciseName,
    required this.logs,
    required this.uid,
    required this.firestoreService,
  });

  /// اگر آخرین ست نسبت به ست ثبت‌شده حدود ۲ هفته قبل، حجم بیشتری نداشته
  /// باشد، یعنی پیشرفتی نبوده (طبق بخش ۱۳ پرامپت).
  bool get _hasStagnated {
    if (logs.length < 2) return false;
    final last = logs.last;
    final twoWeeksAgoTarget = last.date.subtract(const Duration(days: 14));

    // نزدیک‌ترین لاگ به ۱۴ روز قبل از آخرین لاگ را پیدا می‌کنیم
    WorkoutLogModel? reference;
    for (final log in logs) {
      if (log.date.isBefore(last.date) &&
          (reference == null ||
              (log.date.difference(twoWeeksAgoTarget)).abs() <
                  (reference.date.difference(twoWeeksAgoTarget)).abs())) {
        reference = log;
      }
    }
    if (reference == null) return false;
    if (last.date.difference(reference.date).inDays < 10) return false; // داده کافی نیست

    return last.volume <= reference.volume;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exerciseName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                'آخرین: ${logs.last.sets}×${logs.last.reps} @ ${logs.last.weightKg.toStringAsFixed(0)}kg',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          if (_hasStagnated) ...[
            const SizedBox(height: 8),
            const Text(
              '⚠️ حدود ۲ هفته پیشرفتی در این حرکت نبوده — شاید وقتشه برنامه رو عوض کنی.',
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: logs.length < 2
                ? const Center(
                    child: Text(
                      'برای نمودار حداقل ۲ ثبت لازم است',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 34),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (int i = 0; i < logs.length; i++)
                              FlSpot(i.toDouble(), logs[i].weightKg),
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
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            'روند وزنه (کیلوگرم) بر اساس تاریخ ثبت — از ${DateFormat('yyyy/MM/dd').format(logs.first.date)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
