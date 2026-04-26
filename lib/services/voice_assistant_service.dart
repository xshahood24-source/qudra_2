// lib/services/voice_assistant_service.dart
import 'package:logging/logging.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceAssistantService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final Logger _logger = Logger('VoiceAssistantService');

  bool _isListening = false;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _speechToText.initialize(
      onError: (error) {
        _logger.warning('Speech error: $error');
      },
      onStatus: (status) {
        _logger.info('Speech status: $status');
      },
    );

    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);

    _isInitialized = true;
    _logger.info('VoiceAssistantService initialized successfully');
  }

  Future<void> startListening() async {
    if (_isListening || !_isInitialized) return;

    _isListening = true;

    await _speechToText.listen(
      // ignore: deprecated_member_use
      listenMode: ListenMode.confirmation,
      onResult: (result) {
        if (result.finalResult) {
          final command = result.recognizedWords.toLowerCase().trim();
          _logger.info('User said: $command');
          _processVoiceCommand(command);
        }
      },
    );
  }

  void stopListening() {
    if (!_isListening) return;
    _speechToText.stop();
    _isListening = false;
    _logger.info('Stopped listening');
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) return;
    await _flutterTts.stop();
    await _flutterTts.speak(text);
    _logger.info('Speaking: $text');
  }

  void _processVoiceCommand(String command) {
    if (command.contains('animal')) {
      speak('Scanning for animals');
    } else if (command.contains('person') || command.contains('people')) {
      speak('Scanning for people');
    } else if (command.contains('light')) {
      speak('Checking lighting status');
    } else if (command.contains('color')) {
      speak('Scanning for colors');
    } else if (command.contains('help')) {
      speak('You can say animal, person, light, color, or back');
    } else if (command.contains('back')) {
      speak('Going back');
    } else {
      speak('Command not recognized');
    }
  }

  bool get isListening => _isListening;

  /// تنظيف
  void dispose() {
    _speechToText.cancel();
    _flutterTts.stop();
    _logger.info('VoiceAssistantService disposed');
  }
}
