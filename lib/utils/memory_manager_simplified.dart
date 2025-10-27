import 'dart:async';
import 'package:flutter/material.dart';
import 'image_cache_manager.dart';

/// 简化版内存管理
/// 只保留必要的图片缓存管理功能
class MemoryManager {
  static MemoryManager? _instance;
  static MemoryManager get instance => _instance ??= MemoryManager._();

  MemoryManager._();

  Timer? _cacheCleanupTimer;

  // 初始化内存管理
  void initialize() {
    _startCacheCleanup();
  }

  // 启动缓存清理定时器
  void _startCacheCleanup() {
    // 每10分钟清理一次过期缓存
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _performCacheCleanup();
    });
  }

  // 执行缓存清理
  void _performCacheCleanup() {
    try {
      // 清理图片缓存（cached_network_image有内置的过期机制）
      // 这里可以添加其他缓存清理逻辑
    } catch (e) {
      // 执行缓存清理失败
    }
  }

  // 强制清理所有缓存（在内存紧张时调用）
  void forceCleanup() {
    ImageCacheManager.clearImageCache();
    // 调整图片缓存大小限制
    PaintingBinding.instance.imageCache.maximumSize = 100;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100MB
  }

  // 获取内存使用统计
  Map<String, dynamic> getMemoryStats() {
    final imageCache = PaintingBinding.instance.imageCache;
    final cacheStats = ImageCacheManager.getCacheStats();

    return {
      'imageCache': {
        'currentSize': imageCache.currentSize,
        'currentSizeBytes': imageCache.currentSizeBytes,
        'maximumSize': imageCache.maximumSize,
        'maximumSizeBytes': imageCache.maximumSizeBytes,
      },
      'networkCache': cacheStats,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // 释放资源
  void dispose() {
    _cacheCleanupTimer?.cancel();
  }
}