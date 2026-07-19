import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// فرم ثبت دستی روزانه: مطالعه، ورزش، ساعت خواب/بیداری، و خلق‌وخو.
/// به‌صورت StatefulWidget جدا نوشته شده تا کنترلرها و مقدار خلق‌وخو،
/// مستقل از rebuild شدن بقیه‌ی داشبورد (مثلا هنگام لود بریفینگ)، حفظ شوند.
class ManualEntryForm extends StatefulWidget {
  final String uid;
  final FirestoreService firestoreService;

  const ManualEntryForm({super.key, required this.uid, required this.firestoreService});

  @override
  State<ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<ManualEntryForm> {
  final _studyController = TextEditingController();
  final _workoutController = TextEditingController();
  final _sleepHoursController = TextEditingController();
  final _bedTimeController = TextEditingController();
  final _wakeTimeController = TextEditingController();
  int? _moodScore;
  bool _saving = false;

  @override
  void dispose() {
    _studyController.dispose();
    _workoutController.dispose();
    _sleepHoursController.dispose();
    _bedTimeController.dispose();
    _wakeTimeController.dispose();
    super.dispose();
  }

  /// تبدیل رشته‌ی "HH:mm" به عدد اعشاری ساعت (مثلا "23:30" -> ۲۳.۵)
  double? _parseTimeToHour(String text) {
    final parts = text.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h + (m / 60);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'studyMinutes': int.tryParse(_studyController.text) ?? 0,
      'workoutMinutes': int.tryParse(_workoutController.text) ?? 0,
    };

    final sleepHours = double.tryParse(_sleepHoursController.text);
    if (sleepHours != null) data['sleepHours'] = sleepHours;

    final bedTime = _parseTimeToHour(_bedTimeController.text);
    if (bedTime != null) data['bedTimeHour'] = bedTime;

    final wakeTime = _parseTimeToHour(_wakeTimeController.text);
    if (wakeTime != null) data['wakeTimeHour'] = wakeTime;

    if (_moodScore != null) data['moodScore'] = _moodScore;

    await widget.firestoreService.upsertTodayLog(widget.uid, data);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ثبت شد ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ثبت دستی امروز',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _studyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'دقایق مطالعه'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _workoutController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'دقایق ورزش'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sleepHoursController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'ساعت خواب (مثلا 7.5)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _bedTimeController,
                  decoration: const InputDecoration(hintText: 'ساعت خوابیدن (23:30)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _wakeTimeController,
                  decoration: const InputDecoration(hintText: 'ساعت بیداری (07:00)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'خلق‌وخو امروز',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final score = (i + 1) * 2; // ۲،۴،۶،۸،۱۰
              const emojis = ['😞', '😕', '😐', '🙂', '😄'];
              final selected = _moodScore == score;
              return GestureDetector(
                onTap: () => setState(() => _moodScore = score),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.surfaceLight,
                    ),
                  ),
                  child: Text(emojis[i], style: const TextStyle(fontSize: 20)),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}
