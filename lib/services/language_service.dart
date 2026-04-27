// lib/services/language_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  static const String _key = 'app_language_code';

  String _languageCode = 'ar-SA';
  String get languageCode => _languageCode;

  static const List<Map<String, String>> supportedLanguages = [
    {
      'code': 'en-US',
      'name': 'English',
      'nativeName': 'English',
      'flag': '🇺🇸',
    },
    {
      'code': 'ar-SA',
      'name': 'Arabic',
      'nativeName': 'العربية',
      'flag': '🇸🇦',
    },
    {
      'code': 'fr-FR',
      'name': 'French',
      'nativeName': 'Français',
      'flag': '🇫🇷',
    },
    {
      'code': 'de-DE',
      'name': 'German',
      'nativeName': 'Deutsch',
      'flag': '🇩🇪',
    },
    {
      'code': 'es-ES',
      'name': 'Spanish',
      'nativeName': 'Español',
      'flag': '🇪🇸',
    },
    {
      'code': 'tr-TR',
      'name': 'Turkish',
      'nativeName': 'Türkçe',
      'flag': '🇹🇷',
    },
  ];

  String get currentLanguageName {
    final lang = supportedLanguages.firstWhere(
      (l) => l['code'] == _languageCode,
      orElse: () => supportedLanguages.first,
    );
    return '${lang['flag']} ${lang['nativeName']}';
  }

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      _languageCode = saved;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
    notifyListeners();
  }

  void updateLanguage(String newLang) {}
}
