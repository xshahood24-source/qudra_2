// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:qudra_2/services/voice_assistant_service.dart';
import 'screens/splash_screen.dart';

// 👇 ضيف ملف الـ voice service
// import 'voice_assistant_service.dart';

// 👇 navigator key للتحكم في التنقل من أي مكان
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🔥 شغّل الـ Voice Assistant مرة واحدة بس
  VoiceAssistantService().init(); // أو startListening حسب اسم الفنكشن عندك

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 🔥 مهم جدًا
      title: 'Smart Vision Aid',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D5357),
        ),
        useMaterial3: true,
      ),

      // 👇 يفضل تستخدم routes عشان الأوامر الصوتية
      routes: {
        '/home': (context) => const SplashScreen(), // عدلها بعدين للهوم الحقيقي
      },

      home: const SplashScreen(),
    );
  }
}
