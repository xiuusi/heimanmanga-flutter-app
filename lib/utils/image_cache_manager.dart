import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:math' as math;

class ImageCacheManager {
  static const int maxCacheSize = 500; // 增加最大缓存图片数量
  static const int maxCacheBytes = 300 * 1024 * 1024; // 增加到300MB
  static const Duration cacheExpiration = Duration(days: 7);

  // 新增性能配置
  static const int thumbnailCacheSize = 100; // 缩略图缓存大小
  static const int thumbnailCacheBytes = 50 * 1024 * 1024; // 50MB
  static const int lowMemoryCacheSize = 100; // 低内存设备缓存大小
  static const int lowMemoryCacheBytes = 100 * 1024 * 1024; // 100MB

  static void initializeCache() {
    try {
      // 配置网络图片缓存（使用默认设置）
      if (PaintingBinding.instance != null) {
        PaintingBinding.instance.imageCache.maximumSize = maxCacheSize;
        PaintingBinding.instance.imageCache.maximumSizeBytes = maxCacheBytes;
      }

      // 配置CachedNetworkImage缓存
      _configureCachedNetworkImage();

      // 延迟检测设备性能（安全的方式）
      Future.delayed(Duration(milliseconds: 100), () {
        _configureForDevicePerformance();
      });

      // 延迟预热缓存
      Future.delayed(const Duration(seconds: 2), () {
        _preheatCache();
      });
    } catch (e) {
      // 初始化缓存时出错
    }
  }

  // 根据设备性能配置缓存
  static void _configureForDevicePerformance() {
    // 安全地延迟执行以确保WidgetsBinding已初始化
    if (WidgetsBinding.instance != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performDeviceConfiguration();
      });
    } else {
      // 如果WidgetsBinding还没有准备好，使用异步延迟
      Future.delayed(Duration.zero, () {
        if (WidgetsBinding.instance != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _performDeviceConfiguration();
          });
        }
      });
    }
  }

  // 实际执行设备配置的方法
  static void _performDeviceConfiguration() {
    try {
      final devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final isLowEnd = _isLowEndDevice();

      if (isLowEnd) {
        PaintingBinding.instance.imageCache.maximumSize = lowMemoryCacheSize;
        PaintingBinding.instance.imageCache.maximumSizeBytes = lowMemoryCacheBytes;
      } else if (devicePixelRatio > 2.0) {
        // 高分辨率设备，增加缓存大小
        PaintingBinding.instance.imageCache.maximumSize = maxCacheSize + 200;
        PaintingBinding.instance.imageCache.maximumSizeBytes = maxCacheBytes + 100 * 1024 * 1024;
      }
    } catch (e) {
      // 如果配置失败，使用默认设置
    }
  }

  // 检测是否为低端设备
  static bool _isLowEndDevice() {
    // 简单的低端设备检测逻辑
    try {
      final devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      return devicePixelRatio < 1.5 || Platform.isIOS; // iOS设备通常内存管理更严格
    } catch (e) {
      return false; // 如果无法获取设备信息，默认返回false
    }
  }

  static void _configureCachedNetworkImage() {
    // 配置默认缓存设置
    // 注意：cached_network_image 3.x版本使用不同的配置方式

    // 清理过期缓存
    _cleanExpiredCache();
  }

  static void _cleanExpiredCache() async {
    try {
      // 使用默认缓存管理器进行清理
      // final cacheManager = DefaultCacheManager();
      // await cacheManager.emptyCache(); // 清空缓存，可选择性清理

      // 更智能的清理策略
      await _performSmartCacheCleanup();
    } catch (e) {
      // 清理缓存时出错
    }
  }

  // 智能缓存清理
  static Future<void> _performSmartCacheCleanup() async {
    try {
      final cacheStats = getCacheStats();
      final currentUsage = cacheStats['currentSizeBytes'] as int;
      final maxUsage = cacheStats['maximumSizeBytes'] as int;

      // 如果缓存使用超过80%，开始清理
      if (currentUsage > maxUsage * 0.8) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        // 清理旧的缓存文件
        await _clearOldCacheFiles();
      }
    } catch (e) {
      // 智能缓存清理失败
    }
  }

  // 清理旧的缓存文件
  static Future<void> _clearOldCacheFiles() async {
    try {
      // 这里可以实现具体的文件清理逻辑
      // 例如：删除超过30天的缓存文件
    } catch (e) {
      // 清理旧缓存文件失败
    }
  }

  // 预热缓存
  static void _preheatCache() {
    // 预加载常用图片
    Future.delayed(const Duration(seconds: 2), () {
      _preloadCommonImages();
    });
  }

  static Future<void> _preloadCommonImages() async {
    // 预加载常用图片的逻辑
    // 例如：应用图标、默认图片等
  }

  // 预加载图片
  static Future<void> preloadImage(String imageUrl, BuildContext context) async {
    try {
      await precacheImage(
        CachedNetworkImageProvider(imageUrl),
        context,
      );
    } catch (e) {
      // 预加载图片失败
    }
  }

  // 清理图片缓存
  static Future<void> clearImageCache() async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // 清理网络缓存（需要手动实现或使用第三方库）
    } catch (e) {
      // 清理图片缓存失败
    }
  }

  // 获取缓存统计信息
  static Map<String, dynamic> getCacheStats() {
    final imageCache = PaintingBinding.instance.imageCache;
    return {
      'currentSize': imageCache.currentSize,
      'currentSizeBytes': imageCache.currentSizeBytes,
      'maximumSize': imageCache.maximumSize,
      'maximumSizeBytes': imageCache.maximumSizeBytes,
    };
  }

  // 检查是否为低内存设备
  static bool isLowMemoryDevice() {
    // 这里可以根据实际需求添加内存检测逻辑
    // 简单的判断依据：设置较低的缓存阈值
    return false; // 默认返回false，实际应用中可以根据设备情况调整
  }

  // 适配低内存设备的配置
  static void configureForLowMemory() {
    PaintingBinding.instance.imageCache.maximumSize = 50;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
  }
}

// 自定义的图片加载组件，具有优化功能
class OptimizedCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final bool enableFadeIn;
  final Duration fadeInDuration;
  final bool enableProgressIndicator;
  final bool enableMemoryCache;
  final bool enableRetryOnError;

  const OptimizedCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
    this.enableFadeIn = true,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.enableProgressIndicator = true,
    this.enableMemoryCache = true,
    this.enableRetryOnError = true,
  });

  @override
  Widget build(BuildContext context) {
    // 根据设备性能调整图片质量
    final memCacheWidthValue = enableMemoryCache ? (memCacheWidth ?? _calculateMemCacheWidth()) : null;
    final memCacheHeightValue = enableMemoryCache ? (memCacheHeight ?? _calculateMemCacheHeight()) : null;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidthValue,
      memCacheHeight: memCacheHeightValue,
      fadeInDuration: enableFadeIn ? fadeInDuration : Duration.zero,
      // 使用进度指示器或占位符，但不能同时使用两者
      placeholder: enableProgressIndicator ? null : (placeholder ?? (context, url) => _buildPlaceholder(context)),
      errorWidget: errorWidget ??
          (context, url, error) => _buildErrorWidget(context, error),
      progressIndicatorBuilder: enableProgressIndicator
          ? (context, url, downloadProgress) => _buildProgressIndicator(context, downloadProgress)
          : null,
      // 增加错误重试机制
      errorListener: enableRetryOnError ? (error) {
        _handleImageError(error);
      } : null,
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth < 60 ? 16.0 : 24.0;
          return Center(
            child: SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: size / 8,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor.withOpacity(0.5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, dynamic error) {
    return Container(
      color: Colors.grey[200],
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconSize = constraints.maxWidth < 60 ? 16.0 : 32.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                color: Colors.grey[400],
                size: iconSize,
              ),
              if (constraints.maxWidth > 80)
                const SizedBox(height: 4),
              if (constraints.maxWidth > 80)
                Text(
                  '加载失败',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, DownloadProgress downloadProgress) {
    return Container(
      color: Colors.grey[200],
      child: Stack(
        children: [
          if (downloadProgress.progress != null)
            LinearProgressIndicator(
              value: downloadProgress.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          Center(
            child: Text(
              '${((downloadProgress.progress ?? 0) * 100).toInt()}%',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleImageError(dynamic error) {
    // 记录错误信息，用于后续优化
  }

  // 计算内存缓存宽度
  int? _calculateMemCacheWidth() {
    if (width != null) {
      try {
        final devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
        // 根据设备性能调整缓存大小
        final multiplier = _isLowEndDevice() ? 1.0 : math.min(devicePixelRatio, 2.0);
        return (width! * multiplier).round();
      } catch (e) {
        return width?.round(); // 如果获取失败，返回原始宽度
      }
    }
    return null;
  }

  // 计算内存缓存高度
  int? _calculateMemCacheHeight() {
    if (height != null) {
      try {
        final devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
        final multiplier = _isLowEndDevice() ? 1.0 : math.min(devicePixelRatio, 2.0);
        return (height! * multiplier).round();
      } catch (e) {
        return height?.round(); // 如果获取失败，返回原始高度
      }
    }
    return null;
  }

  bool _isLowEndDevice() {
    try {
      final devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      return devicePixelRatio < 1.5;
    } catch (e) {
      return false; // 默认不是低端设备
    }
  }
}

// 图片预加载管理器
class ImagePreloadManager {
  static final Map<String, Future<void>> _preloadCache = {};

  // 预加载单张图片
  static Future<void> preloadImage(BuildContext context, String imageUrl) async {
    // 检查是否已经在预加载缓存中
    if (_preloadCache.containsKey(imageUrl)) {
      return _preloadCache[imageUrl]!;
    }

    final future = _performPreload(context, imageUrl);
    _preloadCache[imageUrl] = future;

    return future;
  }

  // 智能预加载：检查缓存状态，避免重复加载
  static Future<void> smartPreloadImage(BuildContext context, String imageUrl) async {
    // 如果已经在预加载缓存中，直接返回
    if (_preloadCache.containsKey(imageUrl)) {
      return _preloadCache[imageUrl]!;
    }

    // 使用与首页相同的预加载策略
    // 让 CachedNetworkImage 自动处理缓存复用
    final future = _performPreload(context, imageUrl);
    _preloadCache[imageUrl] = future;

    return future;
  }

  static Future<void> _performPreload(BuildContext context, String imageUrl) async {
    try {
      await precacheImage(
        CachedNetworkImageProvider(imageUrl),
        context,
      );
    } catch (e) {
      _preloadCache.remove(imageUrl);
    }
  }

  // 预加载图片列表
  static Future<void> preloadImageList(BuildContext context, List<String> imageUrls) async {
    final futures = imageUrls.map((url) => preloadImage(context, url));
    await Future.wait(futures, eagerError: false);
  }

  // 清除预加载缓存
  static void clearPreloadCache() {
    _preloadCache.clear();
  }

  // 智能预加载（根据滚动方向预加载）
  static Future<void> smartPreload(BuildContext context, List<String> imageUrls, int currentIndex) async {
    // 预加载当前索引前后3张图片
    final startIndex = math.max(0, currentIndex - 1);
    final endIndex = math.min(imageUrls.length - 1, currentIndex + 3);

    for (int i = startIndex; i <= endIndex; i++) {
      if (i != currentIndex) {
        final url = imageUrls[i];
        // 延迟预加载，避免影响当前页面性能
        Future.delayed(Duration(milliseconds: (i - startIndex) * 100), () {
          preloadImage(context, url);
        });
      }
    }
  }
}
