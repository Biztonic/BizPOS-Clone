import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en'); // Default to English
  
  Locale get locale => _locale;
  
  LocaleProvider() {
    _loadLocale();
  }
  
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'Hindi (हिंदी)'},
    {'code': 'bn', 'name': 'Bengali (বাংলা)'},
    {'code': 'mr', 'name': 'Marathi (मराठी)'},
    {'code': 'te', 'name': 'Telugu (తెలుగు)'},
    {'code': 'ta', 'name': 'Tamil (தமிழ்)'},
    {'code': 'gu', 'name': 'Gujarati (ગુજરાતી)'},
    {'code': 'ur', 'name': 'Urdu (اردو)'},
    {'code': 'kn', 'name': 'Kannada (ಕನ್ನಡ)'},
    {'code': 'or', 'name': 'Odia (ଓଡ଼ିଆ)'},
    {'code': 'ml', 'name': 'Malayalam (മലയാളം)'},
  ];

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    _locale = Locale(languageCode);
    notifyListeners();
  }
  
  Future<void> setLocale(String languageCode) async {
    if (languageCode == _locale.languageCode) return;
    
    _locale = Locale(languageCode);
    
    // Persist the selection
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    
    notifyListeners();
  }
  
  // Helper to get language name
  String get currentLanguageName {
    final lang = supportedLanguages.firstWhere(
      (element) => element['code'] == _locale.languageCode,
      orElse: () => supportedLanguages.first,
    );
    return lang['name']!;
  }
}
