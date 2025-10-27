import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModeType {
  light,
  dark,
  auto,
}

class ThemeManager with ChangeNotifier, WidgetsBindingObserver {
  static final ThemeManager _instance = ThemeManager._internal();

  factory ThemeManager() {
    return _instance;
  }

  ThemeManager._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  ThemeModeType _currentThemeMode = ThemeModeType.auto;

  ThemeModeType get currentThemeMode => _currentThemeMode;

  bool get isDarkMode {
    if (_currentThemeMode == ThemeModeType.auto) {
      final brightness = WidgetsBinding.instance.window.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _currentThemeMode == ThemeModeType.dark;
  }

  @override
  void didChangePlatformBrightness() {
    // 当系统主题改变时，如果当前是自动模式，则通知监听器更新
    if (_currentThemeMode == ThemeModeType.auto) {
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeModeType mode) async {
    _currentThemeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    
    // 使用 Future.microtask 延迟通知，避免在构建过程中通知
    Future.microtask(() => notifyListeners());
  }

  Future<void> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getInt('theme_mode');
    if (savedMode != null && savedMode >= 0 && savedMode < ThemeModeType.values.length) {
      _currentThemeMode = ThemeModeType.values[savedMode];
    }
    // 使用 Future.microtask 延迟通知
    Future.microtask(() => notifyListeners());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
