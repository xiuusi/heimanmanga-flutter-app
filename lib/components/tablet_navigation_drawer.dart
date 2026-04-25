import 'package:flutter/material.dart';

/// 平板模式侧边导航栏 — 基于 Material 3 NavigationRail
class TabletNavigationDrawer extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const TabletNavigationDrawer({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onIndexChanged,
      labelType: NavigationRailLabelType.all,
      groupAlignment: 0.0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('首页'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search),
          label: Text('搜索'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.tag_outlined),
          selectedIcon: Icon(Icons.tag),
          label: Text('标签'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: Text('历史'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('设置'),
        ),
      ],
    );
  }
}
