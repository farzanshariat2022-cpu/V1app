import 'dart:convert';
import 'gemini_service.dart';
import 'firestore_service.dart';

/// معادل سمت‌کلاینت Cloud Function `analyzeJournal` از بخش ۵ پرامپت.
/// بعد از ذخیره‌ی هر نوشته، متن با Gemini 1.5 Flash تحلیل می‌شود و «احساس
/// غالب»، «موضوع اصلی» و «یک توصیه کوتاه» استخراج می‌شود.
class JournalAnalysisService {
  final GeminiService _gemini = GeminiService();
  final FirestoreService _firestore = FirestoreService();

  Future<void> analyzeEntry(
    String uid,
    String entryId,
    String text, {
    String? geminiApiKey,
  }) async {
    if (geminiApiKey == null || geminiApiKey.isEmpty) {
      await _firestore.saveJournalAnalysis(
        uid,
        entryId,
        emotion: '—',
        topic: '—',
        recommendation:
            'برای تحلیل هوشمند این نوشته، یک کلید رایگان Gemini در بخش تنظیمات وارد کن.',
      );
      return;
    }

    final prompt = '''
متن ژورنال زیر را که یک دانشجوی دامپزشکی ۲۲ ساله (ENTP) نوشته تحلیل کن:

"""
$text
"""

فقط و فقط یک JSON خام و معتبر برگردان (بدون هیچ توضیح اضافه، بدون بک‌تیک، بدون
کلمه‌ی json قبل از آن)، دقیقاً با این ساختار:
{"emotion": "احساس غالب در ۱ تا ۳ کلمه فارسی", "topic": "موضوع اصلی در ۲ تا ۴ کلمه فارسی", "recommendation": "یک توصیه کوتاه و عملی در یک جمله فارسی"}
''';

    final response = await _gemini.generateText(apiKey: geminiApiKey, prompt: prompt);

    if (response == null || response.isEmpty) {
      await _firestore.saveJournalAnalysis(
        uid,
        entryId,
        emotion: '—',
        topic: '—',
        recommendation: 'تحلیل انجام نشد (مشکل اتصال یا کلید API). بعداً دوباره امتحان کن.',
      );
      return;
    }

    try {
      final cleaned = response.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = jsonDecode(cleaned) as Map<String, dynamic>;

      await _firestore.saveJournalAnalysis(
        uid,
        entryId,
        emotion: (data['emotion'] ?? '—').toString(),
        topic: (data['topic'] ?? '—').toString(),
        recommendation: (data['recommendation'] ?? '').toString(),
      );
    } catch (_) {
      // اگر مدل خروجی غیر-JSON برگرداند، همان متن خام را به‌عنوان توصیه ذخیره می‌کنیم
      await _firestore.saveJournalAnalysis(
        uid,
        entryId,
        emotion: '—',
        topic: '—',
        recommendation: response.length > 200 ? response.substring(0, 200) : response,
      );
    }
  }
}
