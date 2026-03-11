import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeKey = 'appTheme';
  static const String _darkModeKey = 'darkMode';

  static Future<void> setTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeName);
  }

  static Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'blue';
  }

  static Future<void> setDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, enabled);
  }

  static Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  static ThemeData getThemeData(String themeName, bool darkMode) {
    Color primaryColor;
    switch (themeName) {
      case 'green':
        primaryColor = Colors.green;
        break;
      case 'purple':
        primaryColor = Colors.purple;
        break;
      case 'orange':
        primaryColor = Colors.orange;
        break;
      case 'blue':
      default:
        primaryColor = Colors.blue;
    }
    return ThemeData(
      brightness: darkMode ? Brightness.dark : Brightness.light,
      primarySwatch: primaryColor,
      useMaterial3: true,
      fontFamily: 'Inter',
    );
  }
}