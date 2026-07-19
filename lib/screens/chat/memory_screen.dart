import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/memory_item_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// مدیریت حافظه بلندمدت (بخش ۱۲ پرامپت): کاربر می‌تواند مستقیماً چیزی به
/// حافظه‌ی AI اضافه کند، مثلا «سه‌شنبه‌ها از ۴ تا ۷ کلاس دارم».
class MemoryScreen extends StatelessWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser!.uid;
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('حافظه دستیار')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddMemoryDialog(context, uid, firestoreService),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: const Text(
              'هرچی اینجا اضافه کنی، دستیار چت همیشه بهش دسترسی داره — مثلا '
              '«سه‌شنبه‌ها از ۴ تا ۷ کلاس دارم» یا «هدفم قبولی در آزمون دستیاری».',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.6),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MemoryItemModel>>(
              stream: firestoreService.streamMemoryItems(uid),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Text('هنوز چیزی به حافظه اضافه نشده',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.key,
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 3),
                                Text(item.value,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary, fontSize: 13)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: AppColors.textSecondary),
                            onPressed: () => firestoreService.deleteMemoryItem(uid, item.id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMemoryDialog(BuildContext context, String uid, FirestoreService firestoreService) {
    final keyController = TextEditingController();
    final valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('افزودن به حافظه'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(hintText: 'عنوان کوتاه (مثلا: برنامه کلاسی)'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: valueController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'مثلا: سه‌شنبه‌ها از ۴ تا ۷ کلاس دارم'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () async {
              final key = keyController.text.trim();
              final value = valueController.text.trim();
              if (key.isEmpty || value.isEmpty) return;
              await firestoreService.addMemoryItem(uid, key, value);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}
