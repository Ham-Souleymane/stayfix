import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _prefKey = 'stayfix_theme_mode';

  // Always dark — the app uses a luxury dark aesthetic
  ThemeMode _themeMode = ThemeMode.dark;
  double _fontScale = 1.0;

  ThemeProvider() {
    _ensureDarkMode();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => true; // always dark
  double get fontScale => _fontScale;

  /// Clears any previously saved light/system preference and locks dark mode.
  Future<void> _ensureDarkMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, 'dark');
      final scale = prefs.getDouble('stayfix_font_scale');
      if (scale != null) {
        _fontScale = scale;
      }
    } catch (_) {}
    _themeMode = ThemeMode.dark;
    notifyListeners();
  }

  Future<void> setFontScale(double scale) async {
    if (_fontScale == scale) return;
    _fontScale = scale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('stayfix_font_scale', scale);
    } catch (_) {}
  }

  // Keep API surface so no call-sites break, but always stay dark
  Future<void> setThemeMode(ThemeMode mode) async {
    // No-op — app is locked to dark mode
  }

  Future<void> toggleTheme() async {
    // No-op — app is locked to dark mode
  }
}
