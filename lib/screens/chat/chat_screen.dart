import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_message_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import 'memory_screen.dart';

/// چت هوش مصنوعی (بخش ۱۲ پرامپت): به داده‌های زنده‌ی امروز، اهداف، و
/// حافظه‌ی بلندمدت دسترسی دارد.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestoreService = FirestoreService();
  final _chatService = ChatService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  Future<void> _send(String uid) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    _textController.clear();
    setState(() => _sending = true);

    final profile = await _firestoreService.streamUserProfile(uid).first;
    await _chatService.sendMessage(uid, text, geminiApiKey: profile?.geminiApiKey);

    if (!mounted) return;
    setState(() => _sending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('دستیار'),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined, color: AppColors.textSecondary),
            tooltip: 'حافظه دستیار',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MemoryScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _firestoreService.streamChatMessages(uid),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'هرچی می‌خوای بگو — به داده‌های امروزت، اهدافت، و حافظه‌ای که '
                        'براش ثبت کردی دسترسی داره.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _ChatBubble(message: messages[i]),
                );
              },
            ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  SizedBox(width: 8),
                  Text('در حال فکر کردن...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: 'پیامت رو بنویس...'),
                      onSubmitted: (_) => _send(uid),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(uid),
                    icon: const Icon(Icons.send, size: 18),
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessageModel message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.surfaceLight : AppColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6),
        ),
      ),
    );
  }
}
