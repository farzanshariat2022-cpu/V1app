import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import '../../models/habit_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class HabitCard extends StatelessWidget {
  final String uid;
  final HabitModel habit;
  final FirestoreService firestoreService;

  const HabitCard({
    super.key,
    required this.uid,
    required this.habit,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    final failed = habit.failedLast3Days;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: failed ? Border.all(color: AppColors.danger.withOpacity(0.6)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  habit.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              _buildBadge(
                icon: Icons.local_fire_department,
                label: '${habit.currentStreak} روز',
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              _buildBadge(
                icon: Icons.percent,
                label: habit.successRatePercent.toStringAsFixed(0),
                color: AppColors.success,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textSecondary),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
          if (failed) ...[
            const SizedBox(height: 6),
            const Text(
              '⚠️ ۳ روزه این عادت جا افتاده — امروز بشکنش',
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),

          // دکمه بزرگ تیک امروز
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => firestoreService.toggleHabitDate(
                uid,
                habit.id,
                DateTime.now(),
                !habit.isCompletedToday,
              ),
              icon: Icon(
                habit.isCompletedToday ? Icons.check_circle : Icons.radio_button_unchecked,
                color: habit.isCompletedToday ? AppColors.success : AppColors.textSecondary,
                size: 18,
              ),
              label: Text(
                habit.isCompletedToday ? 'امروز انجام شد ✓' : 'امروز انجام بده',
                style: TextStyle(
                  color: habit.isCompletedToday ? AppColors.success : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: habit.isCompletedToday ? AppColors.success : AppColors.surfaceLight,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // نقشه حرارتی (مثل گیت‌هاب) - روی هر روز هم می‌شود مستقیم تپ کرد
          SizedBox(
            height: 120,
            child: HeatMap(
              datasets: habit.heatmapDatasets,
              colorMode: ColorMode.color,
              showText: false,
              scrollable: true,
              size: 16,
              margin: const EdgeInsets.all(2),
              startDate: habit.createdAt.isBefore(
                DateTime.now().subtract(const Duration(days: 150)),
              )
                  ? DateTime.now().subtract(const Duration(days: 150))
                  : habit.createdAt,
              endDate: DateTime.now(),
              defaultColor: AppColors.surfaceLight,
              textColor: AppColors.textSecondary,
              colorsets: const {1: AppColors.primary},
              onClick: (date) {
                final newValue = !habit.isCompletedOn(date);
                firestoreService.toggleHabitDate(uid, habit.id, date, newValue);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف عادت؟'),
        content: Text(
          '«${habit.title}» و کل تاریخچه‌اش حذف می‌شود.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await firestoreService.deleteHabit(uid, habit.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
