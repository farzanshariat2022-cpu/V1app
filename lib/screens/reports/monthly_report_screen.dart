import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/monthly_report_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/monthly_report_service.dart';
import '../../theme/app_theme.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final _firestoreService = FirestoreService();
  final _reportService = MonthlyReportService();
  bool _generating = false;

  String get _currentMonthKey => DateFormat('yyyy-MM').format(DateTime.now());

  Future<void> _generateForCurrentMonth(String uid) async {
    setState(() => _generating = true);
    final profile = await _firestoreService.streamUserProfile(uid).first;
    await _reportService.generateReport(uid, _currentMonthKey, geminiApiKey: profile?.geminiApiKey);
    if (mounted) setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('گزارش ماهانه')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generating ? null : () => _generateForCurrentMonth(uid),
                icon: _generating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.insights, size: 18),
                label: Text(_generating ? 'در حال تحلیل...' : 'ساخت گزارش این ماه'),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MonthlyReportModel>>(
              stream: _firestoreService.streamMonthlyReports(uid),
              builder: (context, snapshot) {
                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'هنوز گزارشی ساخته نشده. دکمه بالا رو بزن.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: reports.length,
                  itemBuilder: (context, i) {
                    final r = reports[i];
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
                              Text(
                                r.month,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (r.isAiGenerated) ...[
                                const SizedBox(width: 6),
                                const Text('(Gemini)',
                                    style: TextStyle(
                                        color: AppColors.textSecondary, fontSize: 11)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            r.summaryText,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              height: 1.8,
                            ),
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
}
