import 'package:intl/intl.dart';
import '../models/chat_message_model.dart';
import 'firestore_service.dart';
import 'gemini_service.dart';

/// چت هوش مصنوعی با حافظه (بخش ۱۲ پرامپت). به حافظه‌ی بلندمدت کاربر،
/// لاگ امروز، و اهداف ریشه‌ای دسترسی دارد تا پاسخ‌هایش با زمینه‌ی واقعی
/// زندگی فرزان باشد، نه کلی‌گویی.
class ChatService {
  final FirestoreService _firestore = FirestoreService();
  final GeminiService _gemini = GeminiService();

  Future<String> sendMessage(String uid, String userText, {String? geminiApiKey}) async {
    // ذخیره‌ی پیام کاربر
    await _firestore.addChatMessage(
      uid,
      ChatMessageModel(id: '', role: ChatRole.user, text: userText, createdAt: DateTime.now()),
    );

    if (geminiApiKey == null || geminiApiKey.isEmpty) {
      const fallback =
          'برای فعال شدن چت هوشمند، یک کلید رایگان Gemini در بخش تنظیمات وارد کن. '
          'فعلاً فقط می‌تونم پیام‌هات رو ذخیره کنم.';
      await _firestore.addChatMessage(
        uid,
        ChatMessageModel(id: '', role: ChatRole.assistant, text: fallback, createdAt: DateTime.now()),
      );
      return fallback;
    }

    final prompt = await _buildContextualPrompt(uid, userText);
    final response = await _gemini.generateText(apiKey: geminiApiKey, prompt: prompt);
    final finalText = response ?? 'مشکلی در اتصال به Gemini پیش اومد. دوباره امتحان کن.';

    await _firestore.addChatMessage(
      uid,
      ChatMessageModel(id: '', role: ChatRole.assistant, text: finalText, createdAt: DateTime.now()),
    );

    return finalText;
  }

  Future<String> _buildContextualPrompt(String uid, String userText) async {
    final memory = await _firestore.getAllMemoryItemsOnce(uid);
    final todayLog = await _firestore.getLogForDate(uid, _firestore.todayKey);
    final rootGoals = await _firestore.streamGoalChildren(uid, null).first;
    final recentMessages = await _firestore.getRecentChatMessagesOnce(uid, limit: 10);

    final memoryText = memory.isEmpty
        ? 'چیزی ثبت نشده'
        : memory.map((m) => '- ${m.key}: ${m.value}').join('\n');

    final goalsText = rootGoals.isEmpty ? 'هنوز ثبت نشده' : rootGoals.map((g) => g.title).join('، ');

    final historyText = recentMessages
        .where((m) => m.text != userText) // پیام فعلی را از تاریخچه حذف می‌کنیم (پایین جدا اضافه می‌شود)
        .map((m) => '${m.role == ChatRole.user ? "فرزان" : "دستیار"}: ${m.text}')
        .join('\n');

    return '''
تو دستیار شخصی و کوچ «فرزان» هستی، دانشجوی دامپزشکی ۲۲ ساله با شخصیت ENTP که
می‌خواد به بهترین نسخه‌ی خودش تبدیل بشه. لحنت مثل یک دوست/مربی نزدیک باشه:
صادق، مستقیم، گاهی ته‌لحن طنز (چون ENTP هست)، نه رسمی و نه بیش‌ازحد مهربان.

حافظه‌ی بلندمدتی که فرزان قبلاً درباره‌ی خودش گفته:
$memoryText

اهداف بلندمدتش: $goalsText

وضعیت امروزش: ${todayLog.studyMinutes} دقیقه مطالعه، ${todayLog.workoutMinutes} دقیقه ورزش،
${todayLog.totalScreenTimeMinutes} دقیقه استفاده از گوشی${todayLog.moodScore != null ? '، خلق‌وخو: ${todayLog.moodScore}/۱۰' : ''}.

${historyText.isEmpty ? '' : 'مکالمه‌ی اخیرتون:\n$historyText\n'}
پیام جدید فرزان: $userText

با توجه به همه‌ی این زمینه (نه فقط جمله‌ی آخر) یک پاسخ کوتاه و مفید به فارسی
بده. اگه پیامش به داده‌های امروزش (مطالعه/ورزش/گوشی/خلق‌وخو) مرتبطه، مستقیم
بهشون اشاره کن، نه اینکه فقط همدلی کنی.
''';
  }
}
