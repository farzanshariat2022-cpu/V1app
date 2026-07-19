import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/decision_service.dart';
import '../../theme/app_theme.dart';

class DecisionScreen extends StatefulWidget {
  const DecisionScreen({super.key});

  @override
  State<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends State<DecisionScreen> {
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _contextController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _decisionService = DecisionService();

  bool _loading = false;
  String? _result;

  Future<void> _decide(String uid) async {
    if (_optionAController.text.trim().isEmpty || _optionBController.text.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _result = null;
    });

    final profile = await _firestoreService.streamUserProfile(uid).first;
    final result = await _decisionService.decide(
      uid,
      optionA: _optionAController.text.trim(),
      optionB: _optionBController.text.trim(),
      context: _contextController.text.trim(),
      geminiApiKey: profile?.geminiApiKey,
    );

    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('کمکم کن تصمیم بگیرم')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _optionAController,
              decoration: const InputDecoration(hintText: 'گزینه A'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _optionBController,
              decoration: const InputDecoration(hintText: 'گزینه B'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contextController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'زمینه‌ی اضافی (اختیاری): مثلا زمان در دسترس، محدودیت‌ها...',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : () => _decide(uid),
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('تحلیلم کن'),
            ),
            if (_result != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _result!,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
