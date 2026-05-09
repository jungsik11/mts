import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChartColorMode {
  traditional, // Red: UP, Blue: DOWN (Korean Standard)
  modern,      // Green: UP, Red: DOWN (US Standard)
}

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  ChartColorMode _chartColorMode = ChartColorMode.traditional;
  bool _isCompactMode = false;
  double _fontSizeFactor = 1.0;

  ThemeMode get themeMode => _themeMode;
  ChartColorMode get chartColorMode => _chartColorMode;
  bool get isCompactMode => _isCompactMode;
  double get fontSizeFactor => _fontSizeFactor;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Theme
    final themeIndex = prefs.getInt('themeMode') ?? 2; // Default to dark (index 2)
    if (themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }

    // Chart Color
    final chartIndex = prefs.getInt('chartColorMode') ?? 0;
    if (chartIndex < ChartColorMode.values.length) {
      _chartColorMode = ChartColorMode.values[chartIndex];
    }

    // Compact Mode
    _isCompactMode = prefs.getBool('isCompactMode') ?? false;

    // Font Size
    _fontSizeFactor = prefs.getDouble('fontSizeFactor') ?? 1.0;

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  Future<void> setChartColorMode(ChartColorMode mode) async {
    _chartColorMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('chartColorMode', mode.index);
  }

  Future<void> toggleCompactMode() async {
    _isCompactMode = !_isCompactMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isCompactMode', _isCompactMode);
  }

  Future<void> setFontSizeFactor(double factor) async {
    _fontSizeFactor = factor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSizeFactor', factor);
  }

  // Helpers for colors based on mode
  Color get upColor => _chartColorMode == ChartColorMode.traditional 
      ? const Color(0xFFFF4B4B) 
      : const Color(0xFF00C076);

  Color get downColor => _chartColorMode == ChartColorMode.traditional 
      ? const Color(0xFF2D5AF7) 
      : const Color(0xFFFF4B4B);
}
