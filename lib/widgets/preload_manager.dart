import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 预加载管理器
class PreloadManager {
  Set<int> _preloadedPages = <int>{};
  static const int _preloadRange = 5;
  static const int _chapterEndPreloadThreshold = 3;
  final Manga manga;
  final Chapter chapter;
  final List<Chapter> chapters;
  List<String> imageUrls;
  bool _isNearChapterEnd = false;
  Timer? _nextChapterPreloadTimer;
  int currentPage = 0;
  int currentChapterIndex = 0;
  BuildContext? context;
  
  Function()? _onNearChapterEnd;
  Function(int, int)? _onPreloadNextChapter;

  PreloadManager({
    required this.manga,
    required this.chapter,
    required this.chapters,
    required this.imageUrls,
    required this.currentPage,
    required this.currentChapterIndex,
    required this.context,
    Function()? onNearChapterEnd,
    Function(int, int)? onPreloadNextChapter,
  }) {
    _onNearChapterEnd = onNearChapterEnd;
    _onPreloadNextChapter = onPreloadNextChapter;
  }

  /// 预加载附近的页面
  void preloadNearbyPages() {
    if (imageUrls.isEmpty || context == null) return;

    int start = (currentPage - _preloadRange).clamp(0, imageUrls.length - 1);
    int end = (currentPage + _preloadRange).clamp(0, imageUrls.length - 1);

    // 智能预加载：优先预加载靠近当前页面的图片
    List<int> pagesToPreload = [];
    for (int i = start; i <= end; i++) {
      if (!_preloadedPages.contains(i)) {
        pagesToPreload.add(i);
      }
    }

    // 按距离排序，优先预加载靠近当前页面的图片
    pagesToPreload.sort((a, b) =>
      (a - currentPage).abs().compareTo((b - currentPage).abs())
    );

    // 渐进式预加载
    for (int i = 0; i < pagesToPreload.length; i++) {
      final pageIndex = pagesToPreload[i];
      _preloadedPages.add(pageIndex);

      // 延迟预加载较远的图片
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (_isValidPageIndex(pageIndex) && context != null) {
          precacheImage(
            CachedNetworkImageProvider(imageUrls[pageIndex]),
            context!,
            onError: (exception, stackTrace) {
              _preloadedPages.remove(pageIndex);
            },
          );
        }
      });
    }

    // 检查是否需要预加载下一章节
    checkNextChapterPreload();
  }

  bool _isValidPageIndex(int index) {
    return context != null && 
           index >= 0 && 
           index < imageUrls.length;
  }

  /// 检查是否需要预加载下一章节
  void checkNextChapterPreload() {
    if (imageUrls.isEmpty) return;

    final isNearEnd = currentPage >= imageUrls.length - _chapterEndPreloadThreshold;

    // 如果接近章节末尾且还没有预加载下一章节
    if (isNearEnd && !_isNearChapterEnd) {
      _isNearChapterEnd = true;
      _onNearChapterEnd?.call();
      preloadNextChapter();
    } else if (!isNearEnd && _isNearChapterEnd) {
      _isNearChapterEnd = false;
      cancelNextChapterPreload();
    }
  }

  /// 预加载下一章节
  Future<void> preloadNextChapter() async {
    final nextChapterIndex = currentChapterIndex + 1;

    // 检查是否有下一章
    if (nextChapterIndex >= chapters.length) {
      return;
    }

    // 取消之前的预加载定时器
    cancelNextChapterPreload();

    // 延迟预加载，避免影响当前章节的加载性能
    _nextChapterPreloadTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final nextChapter = chapters[nextChapterIndex];

        // 获取下一章节的图片列表
        final apiImageFiles = await MangaApiService.getChapterImageFiles(
          manga.id,
          nextChapter.id,
        );

        if (apiImageFiles.isNotEmpty) {
          // 预加载下一章节的前几页
          final preloadCount = math.min(5, apiImageFiles.length);

          for (int i = 0; i < preloadCount; i++) {
            final imageUrl = MangaApiService.getChapterImageUrl(
              manga.id,
              nextChapter.id,
              apiImageFiles[i],
            );

            // 使用延迟预加载避免阻塞
            Future.delayed(Duration(milliseconds: i * 100), () {
              if (context != null) {
                precacheImage(
                  CachedNetworkImageProvider(imageUrl),
                  context!,
                );
              }
            });
          }
        }
      } catch (e) {
        // 预加载下一章节失败，不影响当前阅读
      }
    });
    
    _onPreloadNextChapter?.call(currentChapterIndex, nextChapterIndex);
  }

  /// 取消下一章节预加载
  void cancelNextChapterPreload() {
    _nextChapterPreloadTimer?.cancel();
    _nextChapterPreloadTimer = null;
  }

  /// 清除当前预加载记录
  void clearPreloadedPages() {
    _preloadedPages.clear();
  }

  /// 重置预加载状态
  void reset() {
    _preloadedPages.clear();
    _isNearChapterEnd = false;
  }

  /// 更新图片URLs
  void updateImageUrls(List<String> newImageUrls) {
    imageUrls = newImageUrls;
  }

  /// 更新当前页面
  void updateCurrentPage(int newPage) {
    currentPage = newPage;
  }

  /// 更新当前章节索引
  void updateCurrentChapterIndex(int newChapterIndex) {
    currentChapterIndex = newChapterIndex;
  }
}