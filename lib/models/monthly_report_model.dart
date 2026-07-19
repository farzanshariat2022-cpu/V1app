import 'package:cloud_firestore/cloud_firestore.dart';

/// مدل گزارش ماهانه - نگاشت‌شده روی سند users/{uid}/monthly_reports/{yyyy-MM}
class MonthlyReportModel {
  final String month; // فرمت yyyy-MM
  final String summaryText;
  final DateTime generatedAt;
  final bool isAiGenerated;

  MonthlyReportModel({
    required this.month,
    required this.summaryText,
    required this.generatedAt,
    this.isAiGenerated = false,
  });

  factory MonthlyReportModel.fromMap(String month, Map<String, dynamic> map) {
    return MonthlyReportModel(
      month: month,
      summaryText: map['summaryText'] ?? '',
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAiGenerated: map['isAiGenerated'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'summaryText': summaryText,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'isAiGenerated': isAiGenerated,
    };
  }
}
