import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/manga.dart';

/// 阅读进度数据模型
class ReadingProgress {
  final String mangaId;
  final String chapterId;
  final int currentPage;
  final DateTime lastReadTime;
  final int totalPages;
  final double readingPercentage;
  final bool isMarkedAsRead; // 独立的已阅读标记

  ReadingProgress({
    required this.mangaId,
    required this.chapterId,
    required this.currentPage,
    required this.lastReadTime,
    required this.totalPages,
    required this.readingPercentage,
    this.isMarkedAsRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'mangaId': mangaId,
      'chapterId': chapterId,
      'currentPage': currentPage,
      'lastReadTime': lastReadTime.toIso8601String(),
      'totalPages': totalPages,
      'readingPercentage': readingPercentage,
      'isMarkedAsRead': isMarkedAsRead,
    };
  }

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      mangaId: json['mangaId'],
      chapterId: json['chapterId'],
      currentPage: json['currentPage'],
      lastReadTime: DateTime.parse(json['lastReadTime']),
      totalPages: json['totalPages'] ?? 0,
      readingPercentage: (json['readingPercentage'] ?? 0.0).toDouble(),
      isMarkedAsRead: json['isMarkedAsRead'] ?? false,
    );
  }

  /// 计算阅读百分比
  static double calculatePercentage(int currentPage, int totalPages) {
    if (totalPages <= 0) return 0.0;
    return (currentPage + 1) / totalPages;
  }

  /// 检查是否应该提示跳转（当前章节有进度且不是第一页）
  bool shouldPromptJump(String currentChapterId) {
    // 只有在当前章节有进度且不是第一页时才提示跳转
    final shouldJumpByProgress = chapterId == currentChapterId && currentPage > 0;
    return shouldJumpByProgress;
  }

  /// 检查章节是否已阅读（仅使用独立标记，不依赖阅读进度）
  bool isChapterRead() {
    // 仅使用独立标记来判断是否已阅读
    // 一旦标记为已阅读，就永久保持已阅读状态
    return isMarkedAsRead;
  }
}

/// 阅读进度管理器
class ReadingProgressManager {
  static final ReadingProgressManager _instance = ReadingProgressManager._internal();
  factory ReadingProgressManager() => _instance;
  ReadingProgressManager._internal();

  static const String _progressKey = 'reading_progress';
  SharedPreferences? _prefs;

  /// 初始化
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
  }

  /// 保存阅读进度
  Future<void> saveProgress({
    required Manga manga,
    required Chapter chapter,
    required int currentPage,
    required int totalPages,
  }) async {
    await _ensureInitialized();

    if (_prefs == null) return;

    try {
      // 获取现有进度数据
      final existingData = _prefs!.getString(_progressKey) ?? '{}';
      final Map<String, dynamic> progressMap = json.decode(existingData);

      // 获取或创建当前漫画的章节进度映射
      final mangaKey = manga.id;
      if (!progressMap.containsKey(mangaKey)) {
        progressMap[mangaKey] = {};
      }

      final Map<String, dynamic> chapterProgressMap = progressMap[mangaKey];

      // 检查是否已有阅读记录
      bool isMarkedAsRead = false;
      if (chapterProgressMap.containsKey(chapter.id)) {
        final existingProgress = ReadingProgress.fromJson(chapterProgressMap[chapter.id]);
        // 保留原有的已阅读标记 - 一旦标记为已阅读，就永久保持
        isMarkedAsRead = existingProgress.isMarkedAsRead;
      }

      final progress = ReadingProgress(
        mangaId: manga.id,
        chapterId: chapter.id,
        currentPage: currentPage,
        lastReadTime: DateTime.now(),
        totalPages: totalPages,
        readingPercentage: ReadingProgress.calculatePercentage(currentPage, totalPages),
        isMarkedAsRead: isMarkedAsRead, // 保留原有的已阅读标记
      );

      // 更新或添加当前章节的进度
      chapterProgressMap[chapter.id] = progress.toJson();

      // 保存更新后的数据
      await _prefs!.setString(_progressKey, json.encode(progressMap));

      // 保存阅读进度成功
    } catch (e) {
      // 保存阅读进度失败
    }
  }

  /// 获取指定漫画和章节的阅读进度
  Future<ReadingProgress?> getProgress(String mangaId, {String? chapterId}) async {
    await _ensureInitialized();

    if (_prefs == null) return null;

    try {
      final existingData = _prefs!.getString(_progressKey) ?? '{}';
      final Map<String, dynamic> progressMap = json.decode(existingData);

      if (!progressMap.containsKey(mangaId)) {
        return null;
      }

      final Map<String, dynamic> chapterProgressMap = progressMap[mangaId];

      // 如果指定了章节ID，获取该章节的进度
      if (chapterId != null) {
        if (!chapterProgressMap.containsKey(chapterId)) {
          return null;
        }
        final progress = ReadingProgress.fromJson(chapterProgressMap[chapterId]);
        return progress;
      }

      // 如果没有指定章节ID，返回最新的阅读进度
      if (chapterProgressMap.isEmpty) {
        return null;
      }

      // 找到最新的阅读进度
      ReadingProgress? latestProgress;
      for (final chapterData in chapterProgressMap.values) {
        final progress = ReadingProgress.fromJson(chapterData);
        if (latestProgress == null || progress.lastReadTime.isAfter(latestProgress.lastReadTime)) {
          latestProgress = progress;
        }
      }

      return latestProgress;
    } catch (e) {
      // 获取阅读进度失败
      return null;
    }
  }

  /// 获取所有阅读进度
  Future<Map<String, ReadingProgress>> getAllProgress() async {
    await _ensureInitialized();

    if (_prefs == null) return {};

    try {
      final existingData = _prefs!.getString(_progressKey) ?? '{}';
      final Map<String, dynamic> progressMap = json.decode(existingData);

      final Map<String, ReadingProgress> result = {};
      progressMap.forEach((key, value) {
        result[key] = ReadingProgress.fromJson(value);
      });

      return result;
    } catch (e) {
      return {};
    }
  }

  /// 删除指定漫画的阅读进度
  Future<void> removeProgress(String mangaId) async {
    await _ensureInitialized();

    if (_prefs == null) return;

    try {
      final existingData = _prefs!.getString(_progressKey) ?? '{}';
      final Map<String, dynamic> progressMap = json.decode(existingData);

      progressMap.remove(mangaId);

      await _prefs!.setString(_progressKey, json.encode(progressMap));
    } catch (e) {
      // 删除阅读进度失败
    }
  }

  /// 清除所有阅读进度
  Future<void> clearAllProgress() async {
    await _ensureInitialized();

    if (_prefs == null) return;

    try {
      await _prefs!.remove(_progressKey);
    } catch (e) {
      // 清除阅读进度失败
    }
  }

  /// 获取最近阅读的漫画列表
  Future<List<ReadingProgress>> getRecentRead({int limit = 10}) async {
    final allProgress = await getAllProgress();

    final progressList = allProgress.values.toList()
      ..sort((a, b) => b.lastReadTime.compareTo(a.lastReadTime));

    return progressList.take(limit).toList();
  }

  /// 检查漫画是否有阅读进度
  Future<bool> hasProgress(String mangaId) async {
    final progress = await getProgress(mangaId);
    return progress != null;
  }

  /// 更新阅读时间（用于标记阅读活动）
  Future<void> updateReadTime(String mangaId) async {
    final progress = await getProgress(mangaId);
    if (progress != null) {
      await _ensureInitialized();
      if (_prefs == null) return;

      try {
        final existingData = _prefs!.getString(_progressKey) ?? '{}';
        final Map<String, dynamic> progressMap = json.decode(existingData);

        final updatedProgress = ReadingProgress(
          mangaId: progress.mangaId,
          chapterId: progress.chapterId,
          currentPage: progress.currentPage,
          lastReadTime: DateTime.now(),
          totalPages: progress.totalPages,
          readingPercentage: progress.readingPercentage,
        );

        // 更新章节进度
        if (progressMap.containsKey(mangaId)) {
          final Map<String, dynamic> chapterProgressMap = progressMap[mangaId];
          chapterProgressMap[progress.chapterId] = updatedProgress.toJson();
          await _prefs!.setString(_progressKey, json.encode(progressMap));
        }
      } catch (e) {
        // 更新阅读时间失败
      }
    }
  }

  /// 标记章节为已阅读
  Future<void> markChapterAsRead({
    required String mangaId,
    required String chapterId,
    required bool isRead,
  }) async {
    await _ensureInitialized();

    if (_prefs == null) return;

    try {
      final existingData = _prefs!.getString(_progressKey) ?? '{}';
      final Map<String, dynamic> progressMap = json.decode(existingData);

      if (!progressMap.containsKey(mangaId)) {
        progressMap[mangaId] = {};
      }

      final Map<String, dynamic> chapterProgressMap = progressMap[mangaId];

      if (isRead) {
        // 标记为已阅读 - 设置独立标记为true
        if (chapterProgressMap.containsKey(chapterId)) {
          final existingProgress = ReadingProgress.fromJson(chapterProgressMap[chapterId]);
          chapterProgressMap[chapterId] = ReadingProgress(
            mangaId: mangaId,
            chapterId: chapterId,
            currentPage: existingProgress.currentPage,
            lastReadTime: DateTime.now(),
            totalPages: existingProgress.totalPages,
            readingPercentage: existingProgress.readingPercentage,
            isMarkedAsRead: true, // 设置独立标记
          ).toJson();
        } else {
          // 如果没有现有进度，创建一个标记为已阅读的进度
          chapterProgressMap[chapterId] = ReadingProgress(
            mangaId: mangaId,
            chapterId: chapterId,
            currentPage: 0,
            lastReadTime: DateTime.now(),
            totalPages: 1,
            readingPercentage: 1.0,
            isMarkedAsRead: true, // 设置独立标记
          ).toJson();
        }
      } else {
        // 取消标记 - 清除独立标记，但不删除阅读记录
        if (chapterProgressMap.containsKey(chapterId)) {
          final existingProgress = ReadingProgress.fromJson(chapterProgressMap[chapterId]);
          chapterProgressMap[chapterId] = ReadingProgress(
            mangaId: mangaId,
            chapterId: chapterId,
            currentPage: existingProgress.currentPage,
            lastReadTime: existingProgress.lastReadTime,
            totalPages: existingProgress.totalPages,
            readingPercentage: existingProgress.readingPercentage,
            isMarkedAsRead: false, // 清除独立标记
          ).toJson();
        }
      }

      await _prefs!.setString(_progressKey, json.encode(progressMap));
    } catch (e) {
      // 标记章节状态失败
    }
  }

  /// 获取阅读统计信息
  Future<Map<String, dynamic>> getReadingStats() async {
    final allProgress = await getAllProgress();

    if (allProgress.isEmpty) {
      return {
        'totalManga': 0,
        'totalPages': 0,
        'averageProgress': 0.0,
        'lastReadTime': null,
      };
    }

    final totalManga = allProgress.length;
    int totalPagesRead = 0;
    double totalProgress = 0.0;
    DateTime? lastReadTime;

    for (final progress in allProgress.values) {
      totalPagesRead += progress.currentPage + 1;
      totalProgress += progress.readingPercentage;

      if (lastReadTime == null || progress.lastReadTime.isAfter(lastReadTime)) {
        lastReadTime = progress.lastReadTime;
      }
    }

    return {
      'totalManga': totalManga,
      'totalPages': totalPagesRead,
      'averageProgress': totalProgress / totalManga,
      'lastReadTime': lastReadTime?.toIso8601String(),
    };
  }
}
