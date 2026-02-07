import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode preference values
enum AppThemeMode {
  system,
  light,
  dark,
}

/// Service to manage theme preferences using SharedPreferences
class ThemePreferences extends ChangeNotifier {
  static const _key = 'theme_mode';
  
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _isLoaded = false;

  AppThemeMode get themeMode => _themeMode;
  bool get isLoaded => _isLoaded;

  /// Convert AppThemeMode to Flutter's ThemeMode
  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// Load theme preference from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    
    if (value != null) {
      _themeMode = AppThemeMode.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AppThemeMode.system,
      );
    }
    
    _isLoaded = true;
    notifyListeners();
  }

  /// Save theme preference to SharedPreferences
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Get display name for theme mode
  static String getDisplayName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System default';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  /// Get icon for theme mode
  static IconData getIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.brightness_auto;
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
    }
  }
}
