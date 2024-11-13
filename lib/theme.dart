// theme_provider.dart
import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkTheme;

  ThemeProvider(this._isDarkTheme);

  bool get isDarkTheme => _isDarkTheme;

  void toggleTheme(bool isOn) {
    _isDarkTheme = isOn;
    notifyListeners();
  }
}
