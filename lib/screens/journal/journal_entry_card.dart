import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/journal_entry_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class JournalEntryCard extends StatelessWidget {
  final String uid;
  final JournalEntryModel entry;
  final FirestoreService firestoreService;

  const JournalEntryCard({
    super.key,
    required this.uid,
    required this.entry,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  DateFormat('yyyy/MM/dd - HH:mm').format(entry.createdAt),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.text,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 10),
          if (!entry.analyzed)
            const Row(
              children: [
                SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                SizedBox(width: 8),
                Text(
                  'در حال تحلیل هوش مصنوعی...',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (entry.dominantEmotion != null && entry.dominantEmotion != '—')
                  _buildTag(Icons.mood, entry.dominantEmotion!, AppColors.primary),
                if (entry.mainTopic != null && entry.mainTopic != '—')
                  _buildTag(Icons.topic_outlined, entry.mainTopic!, AppColors.success),
              ],
            ),
            if (entry.recommendation != null && entry.recommendation!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.recommendation!,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف نوشته؟'),
        content: const Text(
          'این نوشته برای همیشه حذف می‌شود.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await firestoreService.deleteJournalEntry(uid, entry.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
