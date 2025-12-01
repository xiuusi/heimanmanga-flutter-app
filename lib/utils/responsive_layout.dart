import 'package:flutter/material.dart';

/// 响应式布局工具类
class ResponsiveLayout {
  /// 检查当前是否为横屏模式（宽度大于高度）
  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }

  /// 检查当前是否为平板模式（横屏时使用侧边栏）
  static bool isTablet(BuildContext context) {
    return isLandscape(context);
  }

  /// 检查当前是否为大平板模式（横屏且宽度相对较大）
  static bool isLargeTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final aspectRatio = size.width / size.height;
    // 横屏且宽高比大于1.3（相对较宽的横屏）
    return isLandscape(context) && aspectRatio > 1.3;
  }

  /// 获取平板模式下的网格列数
  static int getTabletGridColumns(BuildContext context) {
    if (isLargeTablet(context)) {
      return 6; // 大平板：6列
    } else if (isTablet(context)) {
      return 4; // 平板：4列
    } else {
      return 2; // 手机：2列
    }
  }

  /// 获取平板模式下的网格间距
  static double getTabletGridSpacing(BuildContext context) {
    if (isLargeTablet(context)) {
      return 24.0; // 大平板：更大的间距
    } else if (isTablet(context)) {
      return 20.0; // 平板：中等间距
    } else {
      return 16.0; // 手机：默认间距
    }
  }

  /// 获取平板模式下的卡片最大宽度
  static double getTabletCardMaxWidth(BuildContext context) {
    if (isLargeTablet(context)) {
      return 180.0; // 大平板：稍大的卡片
    } else if (isTablet(context)) {
      return 160.0; // 平板：标准卡片
    } else {
      return 200.0; // 手机：保持原有设置
    }
  }

  /// 获取平板模式下的内容边距
  static EdgeInsets getTabletContentPadding(BuildContext context) {
    if (isLargeTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0);
    } else {
      return const EdgeInsets.all(16.0);
    }
  }

  /// 获取平板模式下的字体大小缩放因子
  static double getTabletFontScale(BuildContext context) {
    if (isLargeTablet(context)) {
      return 1.2; // 大平板：字体放大20%
    } else if (isTablet(context)) {
      return 1.1; // 平板：字体放大10%
    } else {
      return 1.0; // 手机：默认大小
    }
  }

  /// 获取平板模式下的封面图片尺寸
  static Size getTabletCoverSize(BuildContext context) {
    if (isLargeTablet(context)) {
      return const Size(200, 300); // 大平板：更大的封面
    } else if (isTablet(context)) {
      return const Size(180, 270); // 平板：中等封面
    } else {
      return const Size(153, 230); // 手机：保持原有设置
    }
  }

  /// 检查是否为手机模式
  static bool isMobile(BuildContext context) {
    // 既不是平板也不是大平板，则为手机
    return !isTablet(context) && !isLargeTablet(context);
  }

  /// 获取侧边栏宽度
  static double getSidebarWidth(BuildContext context) {
    if (isLargeTablet(context)) {
      return 112.0; // 大平板：缩小后的侧边栏
    } else if (isTablet(context)) {
      return 96.0; // 平板：缩小后的侧边栏
    } else {
      return 0.0; // 手机：无侧边栏
    }
  }
}

/// 平板模式下的布局构建器
class TabletLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) mobileBuilder;
  final Widget Function(BuildContext context) tabletBuilder;
  final Widget Function(BuildContext context)? largeTabletBuilder;

  const TabletLayoutBuilder({
    Key? key,
    required this.mobileBuilder,
    required this.tabletBuilder,
    this.largeTabletBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isLargeTablet(context) && largeTabletBuilder != null) {
      return largeTabletBuilder!(context);
    } else if (ResponsiveLayout.isTablet(context)) {
      return tabletBuilder(context);
    } else {
      return mobileBuilder(context);
    }
  }
}

/// 屏幕尺寸枚举
enum ScreenSize {
  small,  // 手机
  medium, // 平板
  large,  // 大平板/桌面
}

/// 响应式构建器
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

  const ResponsiveBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ScreenSize screenSize;

    if (ResponsiveLayout.isLargeTablet(context)) {
      screenSize = ScreenSize.large;
    } else if (ResponsiveLayout.isTablet(context)) {
      screenSize = ScreenSize.medium;
    } else {
      screenSize = ScreenSize.small;
    }

    return builder(context, screenSize);
  }
}