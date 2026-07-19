import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/habit_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'habit_card.dart';

/// صفحه ردیاب عادت (بخش ۴ پرامپت): چک‌باکس روزانه، درصد موفقیت، Heat Map
/// مشابه گیت‌هاب، استریک، و هشدار وقتی یک عادت ۳ روز پشت‌سرهم جا بیفتد.
class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser!.uid;
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('عادت‌ها')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddHabitDialog(context, uid, firestoreService),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<List<HabitModel>>(
        stream: firestoreService.streamHabits(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final habits = snapshot.data ?? [];
          if (habits.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'هنوز عادتی ثبت نکرده‌ای. با دکمه + یکی اضافه کن\n(مثلا «آب سرد صبحگاهی»).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: habits
                .map((h) => HabitCard(uid: uid, habit: h, firestoreService: firestoreService))
                .toList(),
          );
        },
      ),
    );
  }

  void _showAddHabitDialog(BuildContext context, String uid, FirestoreService firestoreService) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('افزودن عادت جدید'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'مثلا: نوشتن ژورنال'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              await firestoreService.addHabit(uid, title);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}
