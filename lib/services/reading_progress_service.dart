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

  ReadingProgress({
    required this.mangaId,
    required this.chapterId,
    required this.currentPage,
    required this.lastReadTime,
    required this.totalPages,
    required this.readingPercentage,
  });

  Map<String, dynamic> toJson() {
    return {
      'mangaId': mangaId,
      'chapterId': chapterId,
      'currentPage': currentPage,
      'lastReadTime': lastReadTime.toIso8601String(),
      'totalPages': totalPages,
      'readingPercentage': readingPercentage,
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
    );
  }

  /// 计算阅读百分比
  static double calculatePercentage(int currentPage, int totalPages) {
    if (totalPages <= 0) return 0.0;
    return (currentPage + 1) / totalPages;
  }

  /// 检查是否应该提示跳转（只要有进度就提示）
  bool shouldPromptJump() {
    final shouldJumpByProgress = currentPage > 0; // 只要有阅读进度就提示
    return shouldJumpByProgress;
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
      final progress = ReadingProgress(
        mangaId: manga.id,
        chapterId: chapter.id,
        currentPage: currentPage,
        lastReadTime: DateTime.now(),
        totalPages: totalPages,
        readingPercentage: ReadingProgress.calculatePercentage(currentPage, totalPages),
      );

      // 获取现有进度数据
      final existingData = _prefs!.getString(_progressKey) ?? '{}';
      final Map<String, dynamic> progressMap = json.decode(existingData);

      // 更新或添加当前漫画的进度
      progressMap[manga.id] = progress.toJson();

      // 保存更新后的数据
      await _prefs!.setString(_progressKey, json.encode(progressMap));
    } catch (e) {
      // 保存阅读进度失败
    }
  }

  /// 获取指定漫画的阅读进度
  Future<ReadingProgress?> getProgress(String mangaId) async {
    await _ensureInitialized();

    if (_prefs == null) return null;

    try {
      final existingData = _prefs!.getString(_progressKey) ?? '{}';
      final Map<String, dynamic> progressMap = json.decode(existingData);

      if (!progressMap.containsKey(mangaId)) {
        return null;
      }

      final progress = ReadingProgress.fromJson(progressMap[mangaId]);
      return progress;
    } catch (e) {
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

        progressMap[mangaId] = updatedProgress.toJson();
        await _prefs!.setString(_progressKey, json.encode(progressMap));
      } catch (e) {
        // 更新阅读时间失败
      }
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
