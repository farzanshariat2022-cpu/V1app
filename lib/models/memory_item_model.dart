import 'package:cloud_firestore/cloud_firestore.dart';

/// مدل حافظه بلندمدت - نگاشت‌شده روی سند users/{uid}/memory/{id}
/// طبق بخش ۱۲ پرامپت: کاربر می‌تواند مستقیماً چیزی به حافظه‌ی AI اضافه کند،
/// مثلا «سه‌شنبه‌ها از ۴ تا ۷ کلاس دارم».
class MemoryItemModel {
  final String id;
  final String key;
  final String value;
  final DateTime createdAt;

  MemoryItemModel({
    required this.id,
    required this.key,
    required this.value,
    required this.createdAt,
  });

  factory MemoryItemModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return MemoryItemModel(
      id: doc.id,
      key: map['key'] ?? '',
      value: map['value'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
