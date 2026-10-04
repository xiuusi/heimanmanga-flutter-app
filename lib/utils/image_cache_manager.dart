import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;
import '../services/api_service.dart';

class ImageCacheManager {
  static const int maxCacheSize = 500; // 增加最大缓存图片数量
  static const int maxCacheBytes = 150 * 1024 * 1024; // 150MB（原 300MB 对低端设备有 OOM 风险）
  static const int highDpiCacheBytes = 200 * 1024 * 1024; // 高分辨率设备的固定上限，避免无界增长

  // 新增性能配置
  static const int thumbnailCacheSize = 100; // 缩略图缓存大小
  static const int thumbnailCacheBytes = 50 * 1024 * 1024; // 50MB
  static const int lowMemoryCacheSize = 100; // 低内存设备缓存大小
  static const int lowMemoryCacheBytes = 100 * 1024 * 1024; // 100MB

  static void initializeCache() {
    try {
      // 配置网络图片缓存（使用默认设置）
      // PaintingBinding.instance 是非空单例，无需判空（原判空会被分析器判为恒真）。
      PaintingBinding.instance.imageCache.maximumSize = maxCacheSize;
      PaintingBinding.instance.imageCache.maximumSizeBytes = maxCacheBytes;

      // 配置CachedNetworkImage缓存
      _configureCachedNetworkImage();

      // 延迟检测设备性能（安全的方式）
      Future.delayed(const Duration(milliseconds: 100), () {
        _configureForDevicePerformance();
      });
    } catch (e) {
      // 初始化缓存时出错
    }
  }

  // 根据设备性能配置缓存
  static void _configureForDevicePerformance() {
    // WidgetsBinding.instance 同样是非空单例，直接注册帧后回调即可。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performDeviceConfiguration();
    });
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
        // 高分辨率设备：适度提高上限，但有固定上限（不再叠加 100MB 无界增长）
        PaintingBinding.instance.imageCache.maximumSize = maxCacheSize + 100;
        PaintingBinding.instance.imageCache.maximumSizeBytes = highDpiCacheBytes;
      }
    } catch (e) {
      // 如果配置失败，使用默认设置
    }
  }

  // 检测是否为低端设备（仅依据设备像素比，统一所有调用点的判断口径）
  static bool _isLowEndDevice() {
    try {
      final devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      return devicePixelRatio < 1.5;
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
      }
    } catch (e) {
      // 智能缓存清理失败
    }
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

    // 准备HTTP头，包含User-Agent
    final Map<String, String>? httpHeaders = MangaApiService.userAgent.isNotEmpty
        ? {'User-Agent': MangaApiService.userAgent}
        : null;

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
      httpHeaders: httpHeaders,
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
                  Theme.of(context).primaryColor.withValues(alpha: 0.5),
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
        // 根据设备性能调整缓存大小（复用统一的低端设备判断）
        final multiplier = ImageCacheManager._isLowEndDevice() ? 1.0 : math.min(devicePixelRatio, 2.0);
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
        final multiplier = ImageCacheManager._isLowEndDevice() ? 1.0 : math.min(devicePixelRatio, 2.0);
        return (height! * multiplier).round();
      } catch (e) {
        return height?.round(); // 如果获取失败，返回原始高度
      }
    }
    return null;
  }
}

// 图片预加载管理器
class ImagePreloadManager {
  static final Map<String, Future<void>> _preloadCache = {};

  // 最多同时跟踪的预加载任务数，防止 map 无界增长
  static const int _maxPreloadCacheSize = 32;

  // 记录一个在途任务；完成后立即移除，因此 map 只保存"正在进行中"的预加载
  static void _trackPreload(String imageUrl, Future<void> future) {
    if (_preloadCache.length >= _maxPreloadCacheSize &&
        !_preloadCache.containsKey(imageUrl)) {
      // 淘汰最旧的条目
      _preloadCache.remove(_preloadCache.keys.first);
    }
    _preloadCache[imageUrl] = future;
    future.whenComplete(() {
      // 只有当前条目仍是这个 future 时才移除，避免误删后来重新加入的同名条目
      if (identical(_preloadCache[imageUrl], future)) {
        _preloadCache.remove(imageUrl);
      }
    });
  }

  // 预加载单张图片
  static Future<void> preloadImage(BuildContext context, String imageUrl) {
    // 检查是否已经在预加载缓存中（并发去重）
    final existing = _preloadCache[imageUrl];
    if (existing != null) {
      return existing;
    }

    final future = _performPreload(context, imageUrl);
    _trackPreload(imageUrl, future);
    return future;
  }

  // 智能预加载：检查缓存状态，避免重复加载
  static Future<void> smartPreloadImage(BuildContext context, String imageUrl) {
    // 如果已经在预加载缓存中，直接返回
    final existing = _preloadCache[imageUrl];
    if (existing != null) {
      return existing;
    }

    // 使用与首页相同的预加载策略
    // 让 CachedNetworkImage 自动处理缓存复用
    final future = _performPreload(context, imageUrl);
    _trackPreload(imageUrl, future);
    return future;
  }

  static Future<void> _performPreload(BuildContext context, String imageUrl) async {
    try {
      await precacheImage(
        CachedNetworkImageProvider(imageUrl),
        context,
      );
    } catch (e) {
      // 失败无需特殊处理：条目会在 whenComplete 中移除
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

}
