import 'package:flutter/material.dart';

/// 屏幕尺寸枚举
enum ScreenSize {
  small,    // 手机 (< 600dp)
  medium,   // 平板 (600-1200dp)
  large,    // 桌面 (> 1200dp)
}

/// 响应式布局工具类
class ResponsiveLayout {
  /// 获取当前屏幕尺寸
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return ScreenSize.small;
    if (width < 1200) return ScreenSize.medium;
    return ScreenSize.large;
  }

  /// 判断是否为平板模式
  static bool isTablet(BuildContext context) {
    return getScreenSize(context) == ScreenSize.medium;
  }

  /// 判断是否为桌面模式
  static bool isDesktop(BuildContext context) {
    return getScreenSize(context) == ScreenSize.large;
  }

  /// 判断是否为手机模式
  static bool isMobile(BuildContext context) {
    return getScreenSize(context) == ScreenSize.small;
  }

  /// 获取自适应网格布局
  static SliverGridDelegate getGridDelegate(BuildContext context) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 2 / 3.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        );
      case ScreenSize.medium:
        return const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
          childAspectRatio: 2 / 3.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        );
      case ScreenSize.large:
        return const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          childAspectRatio: 2 / 3.2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        );
    }
  }

  /// 获取侧边栏宽度
  static double getSidebarWidth(BuildContext context) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return 0; // 手机模式不显示侧边栏
      case ScreenSize.medium:
        return 80; // 平板模式侧边栏宽度（再次缩小）
      case ScreenSize.large:
        return 100; // 桌面模式侧边栏宽度（再次缩小）
    }
  }

  /// 获取内容区域内边距
  static EdgeInsets getContentPadding(BuildContext context) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return const EdgeInsets.symmetric(horizontal: 16);
      case ScreenSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24);
      case ScreenSize.large:
        return const EdgeInsets.symmetric(horizontal: 32);
    }
  }
}

/// 响应式布局构建器
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

  const ResponsiveBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveLayout.getScreenSize(context);
    return builder(context, screenSize);
  }
}

