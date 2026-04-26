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
  Color _accentColor = const Color(0xFFFF6B6B);
  bool _useDynamicColor = true;
  bool _usePureBlack = false;

  ThemeModeType get currentThemeMode => _currentThemeMode;
  Color get accentColor => _accentColor;
  bool get useDynamicColor => _useDynamicColor;
  bool get usePureBlack => _usePureBlack;

  bool get isDarkMode {
    if (_currentThemeMode == ThemeModeType.auto) {
      final brightness = WidgetsBinding.instance.window.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _currentThemeMode == ThemeModeType.dark;
  }

  @override
  void didChangePlatformBrightness() {
    if (_currentThemeMode == ThemeModeType.auto) {
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeModeType mode) async {
    _currentThemeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    Future.microtask(() => notifyListeners());
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color', color.value);
    Future.microtask(() => notifyListeners());
  }

  Future<void> setUseDynamicColor(bool useDynamic) async {
    _useDynamicColor = useDynamic;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_dynamic_color', useDynamic);
    Future.microtask(() => notifyListeners());
  }

  Future<void> setUsePureBlack(bool value) async {
    _usePureBlack = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_pure_black', value);
    Future.microtask(() => notifyListeners());
  }

  Future<void> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getInt('theme_mode');
    if (savedMode != null && savedMode >= 0 && savedMode < ThemeModeType.values.length) {
      _currentThemeMode = ThemeModeType.values[savedMode];
    }

    final savedColor = prefs.getInt('accent_color');
    if (savedColor != null) {
      _accentColor = Color(savedColor);
    }

    final savedDynamic = prefs.getBool('use_dynamic_color');
    if (savedDynamic != null) {
      _useDynamicColor = savedDynamic;
    }

    final savedPureBlack = prefs.getBool('use_pure_black');
    if (savedPureBlack != null) {
      _usePureBlack = savedPureBlack;
    }

    Future.microtask(() => notifyListeners());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
