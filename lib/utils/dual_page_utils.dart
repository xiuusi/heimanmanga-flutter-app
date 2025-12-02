import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

/// 页面布局模式
enum PageLayout {
  single,   // 单页模式
  double,   // 双页模式
  auto,     // 自动模式（横屏双页，竖屏单页）
}

/// 宽图拆分方向
enum SplitSide {
  left,     // 左侧部分
  right,    // 右侧部分
}

/// 双页阅读配置
class DualPageConfig {
  PageLayout pageLayout = PageLayout.auto;
  bool shiftDoublePage = false;      // 是否启用页面移位
  bool invertSplitOrder = false;     // 是否反转拆分顺序
  bool rotateWideToFit = false;      // 是否旋转宽图以适应屏幕

  DualPageConfig();

  // 复制配置
  DualPageConfig copyWith({
    PageLayout? pageLayout,
    bool? shiftDoublePage,
    bool? invertSplitOrder,
    bool? rotateWideToFit,
  }) {
    return DualPageConfig()
      ..pageLayout = pageLayout ?? this.pageLayout
      ..shiftDoublePage = shiftDoublePage ?? this.shiftDoublePage
      ..invertSplitOrder = invertSplitOrder ?? this.invertSplitOrder
      ..rotateWideToFit = rotateWideToFit ?? this.rotateWideToFit;
  }
}

/// 页面分组结果
class PageGroup {
  final int index;           // 分组索引
  final List<String?> urls;  // 页面URL列表（最多2个，null表示空白页）
  final bool isShifted;      // 是否被移位

  PageGroup({
    required this.index,
    required this.urls,
    this.isShifted = false,
  });

  // 获取分组中的实际页面数量（排除空白页）
  int get actualPageCount => urls.where((url) => url != null).length;

  // 是否为单页分组
  bool get isSinglePage => actualPageCount == 1;

  // 是否为双页分组
  bool get isDoublePage => actualPageCount == 2;
}

/// 双页阅读工具类
class DualPageUtils {
  /// 检测是否为宽图（宽高比 > 1）
  static Future<bool> isWideImage(String imageUrl) async {
    try {
      final completer = Completer<ui.Image>();
      final imageProvider = CachedNetworkImageProvider(imageUrl);

      final stream = imageProvider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(info.image);
      });

      stream.addListener(listener);
      final image = await completer.future;
      stream.removeListener(listener);

      return image.width > image.height;
    } catch (e) {
      // 如果检测失败，默认不是宽图
      return false;
    }
  }

  /// 检测是否为长图（高度/宽度 > 3）
  static Future<bool> isTallImage(String imageUrl) async {
    try {
      final completer = Completer<ui.Image>();
      final imageProvider = CachedNetworkImageProvider(imageUrl);

      final stream = imageProvider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(info.image);
      });

      stream.addListener(listener);
      final image = await completer.future;
      stream.removeListener(listener);

      return image.height / image.width > 3;
    } catch (e) {
      // 如果检测失败，默认不是长图
      return false;
    }
  }

  /// 拆分宽图为两半（简单URL拆分，实际应用中需要服务器支持或本地处理）
  static List<String> splitWideImage(String imageUrl, {bool invertOrder = false}) {
    // 在实际应用中，这里应该：
    // 1. 下载图片
    // 2. 使用图像处理库拆分为两半
    // 3. 上传或保存拆分后的图片
    // 4. 返回新的URL列表

    // 目前返回占位URL，实际项目需要实现完整逻辑
    if (invertOrder) {
      return ['$imageUrl?part=right', '$imageUrl?part=left'];
    } else {
      return ['$imageUrl?part=left', '$imageUrl?part=right'];
    }
  }

  /// 分割长图为多个部分
  static List<String> splitTallImage(String imageUrl, {int maxHeight = 2000}) {
    // 在实际应用中，这里应该：
    // 1. 下载图片
    // 2. 按maxHeight分割图片
    // 3. 上传或保存分割后的图片
    // 4. 返回新的URL列表

    // 目前返回占位URL
    return ['$imageUrl?part=1', '$imageUrl?part=2'];
  }

  /// 根据配置对页面URL进行分组
  static List<PageGroup> groupPages(
    List<String> imageUrls,
    DualPageConfig config,
    bool isLandscape,
  ) {
    final actualLayout = _getActualLayout(config, isLandscape);
    if (actualLayout == PageLayout.single) {
      // 单页模式：每个页面独立分组
      return imageUrls.asMap().entries.map((entry) {
        return PageGroup(
          index: entry.key,
          urls: [entry.value],
        );
      }).toList();
    }

    // 双页模式：需要进行分组
    final List<PageGroup> groups = [];
    final List<String?> pages = List.from(imageUrls);

    // 应用页面移位
    if (config.shiftDoublePage && pages.isNotEmpty) {
      // 在第一个位置插入空白页实现移位效果
      pages.insert(0, null);
    }

    // 按每组最多2个页面进行分组
    for (int i = 0; i < pages.length; i += 2) {
      final List<String?> groupUrls = [];
      if (i < pages.length) groupUrls.add(pages[i]);
      if (i + 1 < pages.length) groupUrls.add(pages[i + 1]);

      groups.add(PageGroup(
        index: i ~/ 2,
        urls: groupUrls,
        isShifted: config.shiftDoublePage && i == 0 && pages[0] == null,
      ));
    }

    return groups;
  }

  /// 获取实际布局（考虑自动模式）
  static PageLayout _getActualLayout(DualPageConfig config, bool isLandscape) {
    if (config.pageLayout == PageLayout.auto) {
      return isLandscape ? PageLayout.double : PageLayout.single;
    }
    return config.pageLayout;
  }

  /// 根据设备方向判断是否为横屏
  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }

  /// 根据当前布局计算应该显示的页面索引
  static int getDisplayPageIndex(int currentGroupIndex, int pageInGroup, PageLayout layout) {
    if (layout == PageLayout.single) {
      return currentGroupIndex;
    } else {
      // 双页模式：每个分组可能包含2个页面
      return currentGroupIndex * 2 + pageInGroup;
    }
  }

  /// 根据显示页面索引找到对应的分组索引
  static int findGroupIndex(int displayPageIndex, PageLayout layout, bool shiftDoublePage) {
    if (layout == PageLayout.single) {
      return displayPageIndex;
    } else {
      // 双页模式
      int groupIndex = displayPageIndex ~/ 2;
      if (shiftDoublePage) {
        // 移位后需要调整
        groupIndex = (displayPageIndex + 1) ~/ 2;
      }
      return groupIndex;
    }
  }
}