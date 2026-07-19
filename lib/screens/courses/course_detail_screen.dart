import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chapter_model.dart';
import '../../models/course_model.dart';
import '../../models/topic_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class CourseDetailScreen extends StatelessWidget {
  final CourseModel course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser!.uid;
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: Text(course.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
            onPressed: () => _confirmDeleteCourse(context, uid, firestoreService),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddChapterDialog(context, uid, firestoreService),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<List<ChapterModel>>(
        stream: firestoreService.streamChapters(uid, course.id),
        builder: (context, snapshot) {
          final chapters = snapshot.data ?? [];
          if (chapters.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'هنوز فصلی اضافه نشده. با دکمه + یک فصل بساز (مثلا «فصل ۱: عضلات»).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: chapters
                .map((ch) => _ChapterTile(uid: uid, chapter: ch, firestoreService: firestoreService))
                .toList(),
          );
        },
      ),
    );
  }

  void _showAddChapterDialog(BuildContext context, String uid, FirestoreService firestoreService) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('افزودن فصل'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'مثلا: فصل ۱ - عضلات'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              await firestoreService.addChapter(uid, course.id, title);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCourse(BuildContext context, String uid, FirestoreService firestoreService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف درس؟'),
        content: Text(
          '«${course.title}» و تمام فصل‌ها و مباحثش حذف می‌شود.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await firestoreService.deleteCourseCascade(uid, course.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final String uid;
  final ChapterModel chapter;
  final FirestoreService firestoreService;

  const _ChapterTile({required this.uid, required this.chapter, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          title: Text(
            chapter.title,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          trailing: PopupMenuButton<String>(
            color: AppColors.surfaceLight,
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (v) {
              if (v == 'add_topic') {
                _showAddTopicDialog(context);
              } else if (v == 'delete') {
                _confirmDeleteChapter(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'add_topic', child: Text('افزودن مبحث')),
              const PopupMenuItem(value: 'delete', child: Text('حذف فصل')),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            StreamBuilder<List<TopicModel>>(
              stream: firestoreService.streamTopics(uid, chapter.id),
              builder: (context, snapshot) {
                final topics = snapshot.data ?? [];
                if (topics.isEmpty) {
                  return const Text(
                    'مبحثی ثبت نشده',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  );
                }
                return Column(children: topics.map((t) => _buildTopicRow(context, t)).toList());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicRow(BuildContext context, TopicModel topic) {
    Color statusColor;
    IconData statusIcon;
    switch (topic.status) {
      case TopicStatus.notStarted:
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.circle_outlined;
        break;
      case TopicStatus.inProgress:
        statusColor = AppColors.primary;
        statusIcon = Icons.timelapse;
        break;
      case TopicStatus.completed:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(statusIcon, color: statusColor, size: 20),
            tooltip: 'برای تغییر وضعیت بزن',
            onPressed: () => _cycleTopicStatus(context, topic),
          ),
          Expanded(
            child: Text(
              topic.title,
              style: TextStyle(
                color: topic.status == TopicStatus.completed
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                decoration:
                    topic.status == TopicStatus.completed ? TextDecoration.lineThrough : null,
                fontSize: 13,
              ),
            ),
          ),
          Text(topic.status.label, style: TextStyle(color: statusColor, fontSize: 10)),
          IconButton(
            icon: const Icon(Icons.close, size: 15, color: AppColors.textSecondary),
            onPressed: () => firestoreService.deleteTopic(uid, topic.id),
          ),
        ],
      ),
    );
  }

  Future<void> _cycleTopicStatus(BuildContext context, TopicModel topic) async {
    final next = switch (topic.status) {
      TopicStatus.notStarted => TopicStatus.inProgress,
      TopicStatus.inProgress => TopicStatus.completed,
      TopicStatus.completed => TopicStatus.notStarted,
    };

    final wasFirstCompletion = next == TopicStatus.completed && !topic.reviewsGenerated;
    await firestoreService.updateTopicStatus(uid, topic, next);

    if (wasFirstCompletion && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            '«${topic.title}» تکمیل شد ✓ — تسک‌های مرور علمی برای ۱، ۳، ۷، ۱۵ و ۳۰ روز بعد ساخته شد.',
          ),
        ),
      );
    }
  }

  void _showAddTopicDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('افزودن مبحث'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'مثلا: عضلات دست'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              await firestoreService.addTopic(uid, chapter.courseId, chapter.id, title);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChapter(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف فصل؟'),
        content: Text(
          '«${chapter.title}» و مباحث زیرمجموعه‌اش حذف می‌شود.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await firestoreService.deleteChapterCascade(uid, chapter.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
