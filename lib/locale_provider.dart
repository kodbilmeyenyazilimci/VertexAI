import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

class LocaleProvider extends ChangeNotifier {
  Locale _locale;

  LocaleProvider() : _locale = const Locale('en') {
    _setInitialLocale();
  }

  Locale get locale => _locale;

  Future<void> _setInitialLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguageCode = prefs.getString('language_code');

    // Eğer kayıtlı bir dil varsa onu kullan
    if (savedLanguageCode != null) {
      _locale = Locale(savedLanguageCode);
    } else {
      // Kayıtlı bir dil yoksa cihaz dilini kullan
      Locale deviceLocale = ui.window.locale;
      if (deviceLocale.languageCode == 'tr') {
        _locale = const Locale('tr');
      } else {
        _locale = const Locale('en');
      }
      // Cihaz dilini varsayılan olarak kaydet
      await _saveLocale(_locale);
    }

    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (!['en', 'tr'].contains(locale.languageCode)) return;
    _locale = locale;
    notifyListeners();
    await _saveLocale(locale);
  }

  Future<void> _saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }

  Future<void> clearLocale() async {
    _locale = const Locale('en');
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('language_code');
  }
}
