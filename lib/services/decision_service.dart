import 'firestore_service.dart';
import 'gemini_service.dart';

/// معادل سمت‌کلاینت Cloud Function `helpMeDecide` از بخش ۷ پرامپت.
/// با دسترسی به اهداف بلندمدت کاربر (از تب «اهداف») یک تحلیل هزینه-فایده
/// بین دو گزینه انجام می‌دهد و گزینه‌ی بهتر را پیشنهاد می‌دهد.
class DecisionService {
  final FirestoreService _firestore = FirestoreService();
  final GeminiService _gemini = GeminiService();

  Future<String> decide(
    String uid, {
    required String optionA,
    required String optionB,
    required String context,
    String? geminiApiKey,
  }) async {
    if (geminiApiKey == null || geminiApiKey.isEmpty) {
      return 'برای فعال شدن تحلیل هوشمند تصمیم‌گیری، یک کلید رایگان Gemini در '
          'بخش تنظیمات وارد کن. فعلاً فقط می‌تونم بگم: به هدف‌های بلندمدتت '
          '(تب «اهداف») نگاه کن و ببین کدوم گزینه بیشتر بهت نزدیکت می‌کنه.';
    }

    // جمع‌آوری اهداف ریشه‌ای کاربر برای دادن زمینه به مدل
    final rootGoals = await _firestore.streamGoalChildren(uid, null).first;
    final goalTitles = rootGoals.map((g) => g.title).join('، ');

    final prompt = '''
تو دستیار تصمیم‌گیری «فرزان» هستی، دانشجوی دامپزشکی ۲۲ ساله (ENTP) که این
اهداف بلندمدت رو داره: ${goalTitles.isEmpty ? 'هنوز ثبت نشده' : goalTitles}.

فرزان بین دو گزینه مردده:
گزینه A: $optionA
گزینه B: $optionB

زمینه‌ی اضافی که خودش داده: ${context.isEmpty ? 'چیزی ننوشته' : context}

یک تحلیل هزینه-فایده کوتاه (حداکثر ۶ جمله) بنویس: مزیت/هزینه‌ی هرکدوم رو
خیلی خلاصه بگو، و در پایان صریح بگو کدوم گزینه رو با توجه به اهداف بلندمدتش
پیشنهاد می‌کنی و چرا. لحن مستقیم و عملی، نه کلی‌گویی.
''';

    final result = await _gemini.generateText(apiKey: geminiApiKey, prompt: prompt);
    return result ?? 'مشکلی در اتصال به Gemini پیش اومد. دوباره امتحان کن.';
  }
}
