import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // توجه: در اپ‌های فقط-اندروید با google-services.json در android/app/،
  // نیازی به پاس دادن FirebaseOptions نیست؛ پلاگین Gradle خودش تنظیمات را
  // در زمان بیلد به‌کار می‌گیرد. راهنمای کامل در README.md پروژه.
  await Firebase.initializeApp();

  // یادآورهای صبحگاهی/شبانه (بخش ۱۵ پرامپت). در صورت خطا (مثلا مجوز رد شده)
  // برنامه باید همچنان بالا بیاید، پس داخل try/catch است.
  try {
    await NotificationService().initialize();
  } catch (_) {
    // نبود مجوز نوتیفیکیشن نباید مانع اجرای بقیه‌ی اپ شود
  }

  runApp(const ArchitectApp());
}

class ArchitectApp extends StatelessWidget {
  const ArchitectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'معمار',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        locale: const Locale('fa', 'IR'),
        builder: (context, child) {
          // اجبار جهت راست‌به‌چپ برای کل اپ
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
        home: const AuthGate(),
      ),
    );
  }
}
