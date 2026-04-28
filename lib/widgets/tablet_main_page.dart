import 'package:flutter/material.dart';
import '../utils/responsive_layout.dart';
import '../components/tablet_navigation_drawer.dart';
import 'manga_list_page.dart';
import 'search_page.dart';
import 'tags_page.dart';
import 'history_page.dart';
import 'favorites_page.dart';
import 'settings_page.dart';
import '../utils/theme_manager.dart';
import 'main_navigation_page.dart';

/// 平板模式主页面
class TabletMainPage extends StatefulWidget {
  const TabletMainPage({Key? key}) : super(key: key);

  @override
  State<TabletMainPage> createState() => _TabletMainPageState();
}

class _TabletMainPageState extends State<TabletMainPage> {
  int _currentIndex = 0;
  final ThemeManager _themeManager = ThemeManager();

  final List<Widget> _pages = [
    const MangaListPage(),
    const SearchPage(),
    const TagsPage(),
    const FavoritesPage(),
    const HistoryPage(),
    const SettingsPage(),
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
    if (ResponsiveLayout.isMobile(context)) {
      return const MainNavigationPage();
    }

    return Scaffold(
      body: Row(
        children: [
          TabletNavigationDrawer(
            currentIndex: _currentIndex,
            onIndexChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(child: _pages[_currentIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 64,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            '嘿！——漫',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: _buildThemeIcon(),
            onPressed: _toggleTheme,
            tooltip: _buildThemeTooltip(),
          ),
        ],
      ),
    );
  }
}

/// 响应式主页面 - 根据屏幕尺寸自动选择布局
class ResponsiveMainPage extends StatelessWidget {
  const ResponsiveMainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenSize) {
        switch (screenSize) {
          case ScreenSize.small:
            return const MainNavigationPage();
          case ScreenSize.medium:
          case ScreenSize.large:
            if (!ResponsiveLayout.isWideEnoughForRail(context)) {
              return const MainNavigationPage();
            }
            return const TabletMainPage();
        }
      },
    );
  }
}
