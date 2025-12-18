import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _textScaleFactor = 1.0;

  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void updateTextScale(double scale) {
    if (scale < 0.8 || scale > 1.5) return;
    _textScaleFactor = scale;
    notifyListeners();
  }
}
