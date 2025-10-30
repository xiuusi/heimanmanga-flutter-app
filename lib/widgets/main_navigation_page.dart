import 'package:flutter/material.dart';
import 'manga_list_page.dart';
import 'search_page.dart';
import 'tags_page.dart';
import 'settings_page.dart';
import '../utils/theme_manager.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  final ThemeManager _themeManager = ThemeManager();

  final List<Widget> _pages = [
    const MangaListPage(),
    const SearchPage(),
    const TagsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _themeManager.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeManager.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  void _toggleTheme() {
    final currentMode = _themeManager.currentThemeMode;
    ThemeModeType nextMode;

    // 三态循环切换：自动 → 浅色 → 深色 → 自动
    switch (currentMode) {
      case ThemeModeType.auto:
        nextMode = ThemeModeType.light;
        break;
      case ThemeModeType.light:
        nextMode = ThemeModeType.dark;
        break;
      case ThemeModeType.dark:
        nextMode = ThemeModeType.auto;
        break;
    }

    _themeManager.setThemeMode(nextMode);
  }

  Widget _buildThemeIcon() {
    final currentMode = _themeManager.currentThemeMode;

    switch (currentMode) {
      case ThemeModeType.auto:
        return const Icon(Icons.brightness_auto);
      case ThemeModeType.light:
        return const Icon(Icons.light_mode);
      case ThemeModeType.dark:
        return const Icon(Icons.dark_mode);
    }
  }

  String _buildThemeTooltip() {
    final currentMode = _themeManager.currentThemeMode;

    switch (currentMode) {
      case ThemeModeType.auto:
        return '自动模式（当前：${_themeManager.isDarkMode ? "深色" : "浅色"}）';
      case ThemeModeType.light:
        return '浅色模式（切换到深色模式）';
      case ThemeModeType.dark:
        return '深色模式（切换到自动模式）';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('嘿！——漫'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: [
          IconButton(
            icon: _buildThemeIcon(),
            onPressed: _toggleTheme,
            tooltip: _buildThemeTooltip(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            tooltip: '设置',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ?? Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: '首页',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.search_outlined,
                  activeIcon: Icons.search,
                  label: '搜索',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.tag_outlined,
                  activeIcon: Icons.tag,
                  label: '标签',
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFF6B6B).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive
                  ? const Color(0xFFFF6B6B)
                  : isDarkMode
                    ? const Color(0xFFBBBBBB)
                    : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isActive
                  ? const Color(0xFFFF6B6B)
                  : isDarkMode
                    ? const Color(0xFFBBBBBB)
                    : Colors.grey[600],
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}