// lib/services/voice_assistant_service.dart
import 'dart:nativewrappers/_internal/vm/lib/developer.dart';

import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceAssistantService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isTtsInitialized = false;

  // دالة لتهيئة الـ Service
  Future<void> initialize() async {
    // تهيئة Speech To Text
    await _speechToText.initialize(
      onError: (error) => log("Speech Recognition Error: $error"),
      onStatus: (status) => log("Speech Recognition Status: $status"),
    );

    // تهيئة Text To Speech
    await _flutterTts
        .awaitSpeakCompletion(true); // علشان نتأكد من انتهاء الكلام
    _isTtsInitialized = true;
  }

  // دالة لبدء الاستماع
  Future<void> startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        _isListening = true;
        _speechToText.listen(
          onResult: (result) {
            String recognizedText = result.recognizedWords.toLowerCase();
            log("You said: $recognizedText");
            // معالجة الكلام اللي جاى
            processVoiceCommand(recognizedText);
          },
        );
      }
    }
  }

  // دالة ل(stop) الاستماع
  void stopListening() {
    if (_isListening) {
      _speechToText.stop();
      _isListening = false;
    }
  }

  // دالة لقول نص
  Future<void> speak(String text) async {
    if (_isTtsInitialized) {
      await _flutterTts.speak(text);
    }
  }

  // دالة لمعالجة الأمر الصوتي
  void processVoiceCommand(String command) {
    // ممكن تستخدم switch أو if-else statements
    if (command.contains('animal')) {
      speak("Scanning for animals...");
    } else if (command.contains('person') || command.contains('people')) {
      speak("Scanning for people...");
    } else if (command.contains('light')) {
      speak("Checking lighting status...");
    } else if (command.contains('color')) {
      speak("Scanning for colors...");
    } else if (command.startsWith('say ') || command.startsWith('read ')) {
      // مثال: المستخدم قال "say hello world" أو "read hello world"
      String textToRead = command.substring(4).trim(); // امسح "say " أو "read "
      if (textToRead.isNotEmpty) {
        speak(textToRead);
      } else {
        speak("Please tell me what to say after 'say' or 'read'.");
      }
    } else if (command.contains('help')) {
      speak(
          "You can say animal, person, light, color, say something, read something, or help.");
    } else {
      speak("I didn't understand that command.");
    }
  }

  // دالة للحصول على حالة الاستماع
  bool get isListening => _isListening;

  // ممكن تضيف دوال تانية حسب الحاجة

  // دالة لDispose (مهمة)
  void dispose() {
    _speechToText.cancel();
    _flutterTts.stop();
  }
}
