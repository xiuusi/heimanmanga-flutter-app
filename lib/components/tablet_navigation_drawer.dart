import 'package:flutter/material.dart';

/// 平板模式下的导航抽屉组件 - Generative风格设计
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            // 导航菜单 - 垂直居中
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavButton(
                      context: context,
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: '首页',
                      index: 0,
                    ),
                    const SizedBox(height: 8),
                    _buildNavButton(
                      context: context,
                      icon: Icons.search_outlined,
                      activeIcon: Icons.search,
                      label: '搜索',
                      index: 1,
                    ),
                    const SizedBox(height: 8),
                    _buildNavButton(
                      context: context,
                      icon: Icons.tag_outlined,
                      activeIcon: Icons.tag,
                      label: '标签',
                      index: 2,
                    ),
                    const SizedBox(height: 8),
                    _buildNavButton(
                      context: context,
                      icon: Icons.history_outlined,
                      activeIcon: Icons.history,
                      label: '历史',
                      index: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildNavButton({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = currentIndex == index;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onIndexChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary.withAlpha(20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // 左侧选中指示条
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: 3,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 8),
              // 图标和文字
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isActive ? activeIcon : icon,
                        key: ValueKey(isActive),
                        color: isActive
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        color: isActive
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}