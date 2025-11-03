import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:math' as math;

/// 智能预加载管理器
class SmartPreloadManager {
  static final SmartPreloadManager _instance = SmartPreloadManager._internal();
  factory SmartPreloadManager() => _instance;
  SmartPreloadManager._internal();

  // 预加载缓存
  final Map<String, Set<String>> _preloadedUrls = {};
  final Map<String, Timer> _cleanupTimers = {};

  // 配置参数
  static const int _maxPreloadPerChapter = 10;
  static const Duration _preloadCleanupDelay = Duration(minutes: 10);

  /// 预加载章节图片
  Future<void> preloadChapterImages(
    BuildContext context,
    String chapterId,
    List<String> imageUrls, {
    int preloadCount = 5,
    bool prioritizeNearby = true,
  }) async {
    if (imageUrls.isEmpty) return;

    // 取消之前的清理定时器
    _cleanupTimers[chapterId]?.cancel();

    // 确定预加载数量
    final count = math.min(preloadCount, imageUrls.length);

    // 创建或获取该章节的预加载集合
    if (!_preloadedUrls.containsKey(chapterId)) {
      _preloadedUrls[chapterId] = <String>{};
    }

    final preloadedSet = _preloadedUrls[chapterId]!;

    // 智能选择预加载的图片
    List<String> urlsToPreload = [];

    if (prioritizeNearby) {
      // 优先预加载前几页
      for (int i = 0; i < count; i++) {
        final url = imageUrls[i];
        if (!preloadedSet.contains(url)) {
          urlsToPreload.add(url);
        }
      }
    } else {
      // 均匀预加载
      final step = imageUrls.length ~/ count;
      for (int i = 0; i < count; i++) {
        final index = math.min(i * step, imageUrls.length - 1);
        final url = imageUrls[index];
        if (!preloadedSet.contains(url)) {
          urlsToPreload.add(url);
        }
      }
    }

    // 渐进式预加载
    for (int i = 0; i < urlsToPreload.length; i++) {
      final url = urlsToPreload[i];
      preloadedSet.add(url);

      // 延迟预加载，避免阻塞UI
      Future.delayed(Duration(milliseconds: i * 50), () {
        try {
          precacheImage(
            CachedNetworkImageProvider(url),
            context,
          );
        } catch (e) {
          // 预加载失败，从集合中移除
          preloadedSet.remove(url);
        }
      });
    }

    // 设置清理定时器
    _cleanupTimers[chapterId] = Timer(_preloadCleanupDelay, () {
      _preloadedUrls.remove(chapterId);
    });
  }

  /// 预加载下一章节
  Future<void> preloadNextChapter(
    BuildContext context,
    String mangaId,
    String nextChapterId,
    Future<List<String>> Function() getImageUrls,
  ) async {
    try {
      final imageUrls = await getImageUrls();
      if (imageUrls.isNotEmpty) {
        await preloadChapterImages(
          context,
          nextChapterId,
          imageUrls,
          preloadCount: 5,
          prioritizeNearby: true,
        );
      }
    } catch (e) {
      // 预加载下一章节失败，不影响当前阅读
    }
  }

  /// 检查图片是否已预加载
  bool isImagePreloaded(String chapterId, String imageUrl) {
    return _preloadedUrls[chapterId]?.contains(imageUrl) ?? false;
  }

  /// 清理指定章节的预加载缓存
  void clearChapterPreload(String chapterId) {
    _preloadedUrls.remove(chapterId);
    _cleanupTimers[chapterId]?.cancel();
    _cleanupTimers.remove(chapterId);
  }

  /// 清理所有预加载缓存
  void clearAllPreloads() {
    _preloadedUrls.clear();
    _cleanupTimers.values.forEach((timer) => timer.cancel());
    _cleanupTimers.clear();
  }

  /// 获取预加载统计信息
  Map<String, dynamic> getPreloadStats() {
    int totalPreloaded = 0;
    _preloadedUrls.forEach((chapterId, urls) {
      totalPreloaded += urls.length;
    });

    return {
      'totalChapters': _preloadedUrls.length,
      'totalPreloadedImages': totalPreloaded,
      'chapters': _preloadedUrls.keys.toList(),
    };
  }
}

/// 阅读行为分析器
class ReadingBehaviorAnalyzer {
  static final ReadingBehaviorAnalyzer _instance = ReadingBehaviorAnalyzer._internal();
  factory ReadingBehaviorAnalyzer() => _instance;
  ReadingBehaviorAnalyzer._internal();

  final List<DateTime> _pageTurnTimes = [];
  static const int _maxSamples = 10;

  /// 记录翻页时间
  void recordPageTurn() {
    _pageTurnTimes.add(DateTime.now());

    // 保持最近的数据
    if (_pageTurnTimes.length > _maxSamples) {
      _pageTurnTimes.removeAt(0);
    }
  }

  /// 计算平均阅读速度（页/秒）
  double getAverageReadingSpeed() {
    if (_pageTurnTimes.length < 2) return 3.0; // 默认3秒一页

    double totalSeconds = 0;
    for (int i = 1; i < _pageTurnTimes.length; i++) {
      final duration = _pageTurnTimes[i].difference(_pageTurnTimes[i - 1]);
      totalSeconds += duration.inMilliseconds / 1000.0;
    }

    final averageSeconds = totalSeconds / (_pageTurnTimes.length - 1);
    return averageSeconds;
  }

  /// 预测预加载需求
  int predictPreloadCount() {
    final speed = getAverageReadingSpeed();

    // 根据阅读速度调整预加载数量
    if (speed < 2.0) {
      return 8; // 快速阅读，需要更多预加载
    } else if (speed < 5.0) {
      return 5; // 正常阅读速度
    } else {
      return 3; // 慢速阅读，减少预加载
    }
  }

  /// 清理数据
  void clear() {
    _pageTurnTimes.clear();
  }
}