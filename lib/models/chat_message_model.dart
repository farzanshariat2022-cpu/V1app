import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatRole { user, assistant }

/// مدل پیام چت - نگاشت‌شده روی سند users/{uid}/chat_messages/{id}
class ChatMessageModel {
  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessageModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return ChatMessageModel(
      id: doc.id,
      role: map['role'] == 'assistant' ? ChatRole.assistant : ChatRole.user,
      text: map['text'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role == ChatRole.assistant ? 'assistant' : 'user',
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
