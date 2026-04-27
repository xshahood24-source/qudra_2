import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/material.dart';

// ✅ تعريف الـ navigatorKey هنا ليكون متاحاً في كل مكان
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class VoiceAssistantService {
  // ✅ Singleton
  static final VoiceAssistantService _instance =
      VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal();

  // 🎤 Speech To Text
  final stt.SpeechToText _speech = stt.SpeechToText();

  // 🔊 Text To Speech
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;

  // =========================
  // 🚀 INIT (إضافة الـ async والـ await لضمان الجاهزية)
  // =========================
  Future<void> init() async {
    await _initTTS();
    await _initSTT();
    startListening();
  }

  // =========================
  // 🔊 TTS Setup
  // =========================
  Future<void> _initTTS() async {
    await _tts.setLanguage("ar-EG"); // عربي
    await _tts.setSpeechRate(0.5);
  }

  // =========================
  // 🎤 STT Setup
  // =========================
  Future<void> _initSTT() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Status: $status'),
      onError: (error) => print('Error: $error'),
    );
    if (!available) {
      print("The user has denied the use of speech recognition.");
    }
  }

  // =========================
  // 🎤 Start Listening
  // =========================
  void startListening() async {
    if (_isListening) return;

    _isListening = true;

    await _speech.listen(
      onResult: (result) {
        String text = result.recognizedWords.toLowerCase();
        print("🎤 Heard: $text");

        // إذا انتهى التعرف على الكلمات، نعالج الأمر
        if (result.finalResult) {
          handleCommand(text);
          _isListening = false; // إعادة التعيين ليتمكن من الاستماع مرة أخرى
          startListening();
        }
      },
    );
  }

  // =========================
  // 🧠 Handle Commands
  // =========================
  void handleCommand(String command) {
    if (command.contains("home") || command.contains("الرئيسية")) {
      speak("فتح الصفحة الرئيسية");
      navigatorKey.currentState?.pushNamed('/home');
    } else if (command.contains("settings") || command.contains("الإعدادات")) {
      speak("فتح الإعدادات");
      navigatorKey.currentState?.pushNamed('/settings');
    } else if (command.contains("back") || command.contains("رجوع")) {
      speak("رجوع");
      navigatorKey.currentState?.pop();
    } else {
      // يمكنك تركها فارغة إذا لا تريد أن يتحدث البرنامج عند كل صوت عشوائي
      print("Command not recognized");
    }
  }

  // =========================
  // 🔊 Speak
  // =========================
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  // =========================
  // ⛔ Stop & Dispose (تمت إضافة Dispose هنا)
  // =========================
  void stopListening() async {
    _isListening = false;
    await _speech.stop();
  }

  void dispose() {
    stopListening();
    _tts.stop();
    print("✅ VoiceAssistantService Disposed");
  }
}
