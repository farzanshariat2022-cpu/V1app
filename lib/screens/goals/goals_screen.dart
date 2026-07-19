import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/goal_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'goal_node_tile.dart';

/// صفحه ریشه‌ی سیستم هدف (بخش ۲ پرامپت): هدف اصلی -> پروژه -> نقطه عطف ->
/// هفته -> روز -> تسک. هر گره با ExpansionTile باز/بسته می‌شود.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser!.uid;
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('اهداف')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddRootGoalDialog(context, uid, firestoreService),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<List<GoalModel>>(
        stream: firestoreService.streamGoalChildren(uid, null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final goals = snapshot.data ?? [];
          if (goals.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'هنوز هدف یا پروژه‌ای ثبت نکرده‌ای. با دکمه + یک هدف اصلی '
                  '(مثلا «دامپزشک موفق») یا یک پروژه مستقل (مثلا «اپلیکیشن معمار») بساز.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: goals
                .map((g) => GoalNodeTile(uid: uid, goal: g, firestoreService: firestoreService))
                .toList(),
          );
        },
      ),
    );
  }

  void _showAddRootGoalDialog(
    BuildContext context,
    String uid,
    FirestoreService firestoreService,
  ) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    GoalNodeType selectedType = GoalNodeType.goal;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('افزودن ریشه جدید'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<GoalNodeType>(
                segments: const [
                  ButtonSegment(value: GoalNodeType.goal, label: Text('هدف اصلی')),
                  ButtonSegment(value: GoalNodeType.project, label: Text('پروژه مستقل')),
                ],
                selected: {selectedType},
                onSelectionChanged: (s) => setState(() => selectedType = s.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: selectedType == GoalNodeType.goal
                      ? 'مثلا: دامپزشک موفق'
                      : 'مثلا: اپلیکیشن معمار',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(hintText: 'توضیحات (اختیاری)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                await firestoreService.addGoal(
                  uid,
                  GoalModel(
                    id: '',
                    title: title,
                    description: descController.text.trim(),
                    type: selectedType,
                    parentId: null,
                    createdAt: DateTime.now(),
                    manualProgress: selectedType == GoalNodeType.project ? 0 : null,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }
}
