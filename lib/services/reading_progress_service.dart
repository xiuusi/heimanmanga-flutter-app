import '../models/manga.dart';
import 'drift_reading_progress_manager.dart';

/// 阅读进度数据模型
class ReadingProgress {
  final String mangaId;
  final String chapterId;
  final String chapterTitle;
  final int chapterNumber;
  final int currentPage;
  final DateTime lastReadTime;
  final int totalPages;
  final double readingPercentage;
  final bool isMarkedAsRead;
  final int readingDuration;

  ReadingProgress({
    required this.mangaId,
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.currentPage,
    required this.lastReadTime,
    required this.totalPages,
    required this.readingPercentage,
    this.isMarkedAsRead = false,
    this.readingDuration = 0,
  });

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

  /// 检查章节是否已阅读（仅使用独立标记）
  bool isChapterRead() {
    // 仅使用独立标记来判断是否已阅读
    // 一旦标记为已阅读，就永久保持已阅读状态
    return isMarkedAsRead;
  }
}

/// 阅读进度管理器 - 基础接口
abstract class ReadingProgressManager {
  /// 初始化
  Future<void> init();

  /// 保存阅读进度
  Future<void> saveProgress({
    required Manga manga,
    required Chapter chapter,
    required int currentPage,
    required int totalPages,
  });

  /// 获取指定漫画和章节的阅读进度
  Future<ReadingProgress?> getProgress(String mangaId, {String? chapterId});

  /// 标记章节为已阅读
  Future<void> markChapterAsRead({
    required String mangaId,
    required String chapterId,
    required bool isRead,
  });

  /// 获取阅读统计信息
  Future<Map<String, dynamic>> getReadingStats();

  /// 获取最近阅读的漫画列表
  Future<List<ReadingProgress>> getRecentRead({int limit = 10, int offset = 0});

  /// 检查漫画是否有阅读进度
  Future<bool> hasProgress(String mangaId);
}

/// 全局阅读进度管理器实例
class ReadingProgressService {
  static final ReadingProgressService _instance = ReadingProgressService._internal();
  factory ReadingProgressService() => _instance;
  ReadingProgressService._internal();

  ReadingProgressManager? _manager;

  /// 设置存储管理器
  void setManager(ReadingProgressManager manager) {
    _manager = manager;
  }

  /// 获取管理器实例
  ReadingProgressManager get manager {
    // 默认使用Drift存储管理器
    _manager ??= DriftReadingProgressManager();
    return _manager!;
  }

  /// 初始化
  Future<void> init() async {
    await manager.init();
  }

  /// 保存阅读进度
  Future<void> saveProgress({
    required Manga manga,
    required Chapter chapter,
    required int currentPage,
    required int totalPages,
  }) async {
    await manager.saveProgress(
      manga: manga,
      chapter: chapter,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  /// 获取阅读进度
  Future<ReadingProgress?> getProgress(String mangaId, {String? chapterId}) async {
    return await manager.getProgress(mangaId, chapterId: chapterId);
  }

  /// 标记章节为已阅读
  Future<void> markChapterAsRead({
    required String mangaId,
    required String chapterId,
    required bool isRead,
  }) async {
    await manager.markChapterAsRead(
      mangaId: mangaId,
      chapterId: chapterId,
      isRead: isRead,
    );
  }

  /// 获取阅读统计
  Future<Map<String, dynamic>> getReadingStats() async {
    return await manager.getReadingStats();
  }

  /// 获取最近阅读
  Future<List<ReadingProgress>> getRecentRead({int limit = 10, int offset = 0}) async {
    return await manager.getRecentRead(limit: limit, offset: offset);
  }

  /// 检查是否有进度
  Future<bool> hasProgress(String mangaId) async {
    return await manager.hasProgress(mangaId);
  }

  /// 更新阅读时长
  Future<void> updateReadingDuration({
    required String chapterId,
    required int durationSeconds,
  }) async {
    if (_manager is DriftReadingProgressManager) {
      await (_manager as DriftReadingProgressManager).updateReadingDuration(
        chapterId: chapterId,
        durationSeconds: durationSeconds,
      );
    }
  }

  /// 清除所有阅读历史记录
  Future<void> clearAllHistory() async {
    if (_manager is DriftReadingProgressManager) {
      await (_manager as DriftReadingProgressManager).clearAllHistory();
    }
  }

  /// 获取总的历史记录数量
  Future<int> getTotalHistoryCount() async {
    if (_manager is DriftReadingProgressManager) {
      return await (_manager as DriftReadingProgressManager).getTotalHistoryCount();
    }
    return 0;
  }
}