import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/course_model.dart';
import '../../models/topic_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'course_detail_screen.dart';

/// صفحه مدیریت درس (بخش ۹ پرامپت): فهرست درس‌ها با نوار آمادگی امتحان
/// (تعداد مباحث تکمیل‌شده / کل مباحث) و شمارش معکوس تا تاریخ امتحان.
class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser!.uid;
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('درس‌ها')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddCourseDialog(context, uid, firestoreService),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<List<CourseModel>>(
        stream: firestoreService.streamCourses(uid),
        builder: (context, snapshot) {
          final courses = snapshot.data ?? [];
          if (courses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'هنوز درسی ثبت نکرده‌ای. با دکمه + یک درس (مثلا «آناتومی») بساز.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: courses
                .map((c) => _CourseCard(uid: uid, course: c, firestoreService: firestoreService))
                .toList(),
          );
        },
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context, String uid, FirestoreService firestoreService) {
    final titleController = TextEditingController();
    DateTime? examDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('افزودن درس'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: 'مثلا: آناتومی'),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  examDate == null
                      ? 'تاریخ امتحان (اختیاری)'
                      : DateFormat('yyyy/MM/dd').format(examDate!),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                trailing: const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) setState(() => examDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                await firestoreService.addCourse(uid, title, examDate);
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

class _CourseCard extends StatelessWidget {
  final String uid;
  final CourseModel course;
  final FirestoreService firestoreService;

  const _CourseCard({required this.uid, required this.course, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
      ),
      child: Container(
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
                    course.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (course.daysUntilExam != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (course.daysUntilExam! <= 7 ? AppColors.danger : AppColors.primary)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      course.daysUntilExam! >= 0
                          ? '${course.daysUntilExam} روز تا امتحان'
                          : 'امتحان گذشت',
                      style: TextStyle(
                        color: course.daysUntilExam! <= 7 ? AppColors.danger : AppColors.primary,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<TopicModel>>(
              future: firestoreService.getTopicsForCourseOnce(uid, course.id),
              builder: (context, snapshot) {
                final topics = snapshot.data ?? [];
                final completed = topics.where((t) => t.status == TopicStatus.completed).length;
                final total = topics.length;
                final progress = total == 0 ? 0.0 : completed / total;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      total == 0 ? 'هنوز مبحثی اضافه نشده' : '$completed از $total مبحث تکمیل شده',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
