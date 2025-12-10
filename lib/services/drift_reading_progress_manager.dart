import 'package:drift/drift.dart';
import '../models/drift_models.dart';
import '../models/manga.dart';
import 'reading_progress_service.dart';

/// Drift持久化存储管理器（兼容 drift 2.15.0）
class DriftReadingProgressManager implements ReadingProgressManager {
  AppDatabase? _database;

  @override
  Future<void> init() async {
    if (_database == null) {
      _database = AppDatabase();
    }
  }

  @override
  Future<void> saveProgress({
    required Manga manga,
    required Chapter chapter,
    required int currentPage,
    required int totalPages,
  }) async {
    await init();

    // 查找或创建漫画进度
    final mangaQuery = _database!.select(_database!.mangaProgresses)
      ..where((tbl) => tbl.mangaId.equals(manga.id));
    final mangaProgressList = await mangaQuery.get();

    if (mangaProgressList.isEmpty) {
      await _database!.into(_database!.mangaProgresses).insert(
        MangaProgressesCompanion.insert(
          mangaId: manga.id,
          title: manga.title,
          author: manga.author,
          coverPath: Value(manga.coverPath),
          lastReadTime: DateTime.now(),
        ),
      );
    } else {
      final mangaProgress = mangaProgressList.first;
      await (_database!.update(_database!.mangaProgresses)
            ..where((tbl) => tbl.id.equals(mangaProgress.id)))
          .write(
        MangaProgressesCompanion(
          lastReadTime: Value(DateTime.now()),
        ),
      );
    }

    // 查找或创建章节进度
    final chapterQuery = _database!.select(_database!.chapterProgresses)
      ..where((tbl) => tbl.chapterId.equals(chapter.id));
    final chapterProgressList = await chapterQuery.get();

    if (chapterProgressList.isEmpty) {
      await _database!.into(_database!.chapterProgresses).insert(
        ChapterProgressesCompanion.insert(
          chapterId: chapter.id,
          mangaId: manga.id,
          title: chapter.title,
          number: chapter.number,
          currentPage: currentPage,
          totalPages: totalPages,
          readingPercentage: ReadingProgress.calculatePercentage(currentPage, totalPages),
          isMarkedAsRead: const Value(false),
          lastReadTime: DateTime.now(),
        ),
      );
    } else {
      final chapterProgress = chapterProgressList.first;
      // 保留原有的已阅读标记
      await (_database!.update(_database!.chapterProgresses)
            ..where((tbl) => tbl.id.equals(chapterProgress.id)))
          .write(
        ChapterProgressesCompanion(
          currentPage: Value(currentPage),
          totalPages: Value(totalPages),
          readingPercentage: Value(ReadingProgress.calculatePercentage(currentPage, totalPages)),
          lastReadTime: Value(DateTime.now()),
        ),
      );
    }

  }

  @override
  Future<ReadingProgress?> getProgress(String mangaId, {String? chapterId}) async {
    await init();

    if (chapterId != null) {
      final chapterQuery = _database!.select(_database!.chapterProgresses)
        ..where((tbl) => tbl.chapterId.equals(chapterId));
      final chapterProgressList = await chapterQuery.get();

      if (chapterProgressList.isNotEmpty) {
        final chapterProgress = chapterProgressList.first;
        return ReadingProgress(
          mangaId: chapterProgress.mangaId,
          chapterId: chapterProgress.chapterId,
          chapterTitle: chapterProgress.title,
          chapterNumber: chapterProgress.number,
          currentPage: chapterProgress.currentPage,
          lastReadTime: chapterProgress.lastReadTime,
          totalPages: chapterProgress.totalPages,
          readingPercentage: chapterProgress.readingPercentage,
          isMarkedAsRead: chapterProgress.isMarkedAsRead,
          readingDuration: chapterProgress.readingDuration,
        );
      }
    } else {
      // 查找该漫画的最新进度
      final latestQuery = _database!.select(_database!.chapterProgresses)
        ..where((tbl) => tbl.mangaId.equals(mangaId))
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.lastReadTime)]);
      final latestChapterProgressList = await latestQuery.get();

      if (latestChapterProgressList.isNotEmpty) {
        final latestChapterProgress = latestChapterProgressList.first;
        return ReadingProgress(
          mangaId: latestChapterProgress.mangaId,
          chapterId: latestChapterProgress.chapterId,
          chapterTitle: latestChapterProgress.title,
          chapterNumber: latestChapterProgress.number,
          currentPage: latestChapterProgress.currentPage,
          lastReadTime: latestChapterProgress.lastReadTime,
          totalPages: latestChapterProgress.totalPages,
          readingPercentage: latestChapterProgress.readingPercentage,
          isMarkedAsRead: latestChapterProgress.isMarkedAsRead,
          readingDuration: latestChapterProgress.readingDuration,
        );
      }
    }

    return null;
  }

  @override
  Future<void> markChapterAsRead({
    required String mangaId,
    required String chapterId,
    required bool isRead,
  }) async {
    await init();

    final chapterQuery = _database!.select(_database!.chapterProgresses)
      ..where((tbl) => tbl.chapterId.equals(chapterId));
    final chapterProgressList = await chapterQuery.get();

    if (chapterProgressList.isNotEmpty) {
      final chapterProgress = chapterProgressList.first;
      await (_database!.update(_database!.chapterProgresses)
            ..where((tbl) => tbl.id.equals(chapterProgress.id)))
          .write(
        ChapterProgressesCompanion(
          isMarkedAsRead: Value(isRead),
          lastReadTime: Value(DateTime.now()),
        ),
      );
    } else {
      // 如果没有现有进度，创建一个标记为已阅读的进度
      await _database!.into(_database!.chapterProgresses).insert(
        ChapterProgressesCompanion.insert(
          chapterId: chapterId,
          mangaId: mangaId,
          title: 'Unknown',
          number: 0,
          currentPage: 0,
          totalPages: 1,
          readingPercentage: 1.0,
          isMarkedAsRead: Value(isRead),
          lastReadTime: DateTime.now(),
        ),
      );
    }

  }

  @override
  Future<Map<String, dynamic>> getReadingStats() async {
    await init();

    final mangaCount = await _database!.mangaProgresses.count().get();
    final chapterCount = await _database!.chapterProgresses.count().get();

    final allChaptersQuery = _database!.select(_database!.chapterProgresses);
    final allChapters = await allChaptersQuery.get();

    final totalPagesRead = allChapters.fold(0, (sum, chapter) => sum + chapter.currentPage + 1);
    final averageProgress = allChapters.isEmpty
        ? 0.0
        : allChapters.map((chapter) => chapter.readingPercentage).reduce((a, b) => a + b) / allChapters.length;

    return {
      'totalManga': mangaCount,
      'totalPages': totalPagesRead,
      'averageProgress': averageProgress,
      'lastReadTime': null,
    };
  }

  @override
  Future<List<ReadingProgress>> getRecentRead({int limit = 10, int offset = 0}) async {
    await init();

    // 使用窗口函数按漫画分组，取每个漫画的最新章节记录
    // 按最后阅读时间降序排列，如果时间相同则按章节号降序（取最新章节）
    final query = '''
      WITH ranked_chapters AS (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY manga_id ORDER BY last_read_time DESC, number DESC) as rn
        FROM chapter_progresses
      )
      SELECT * FROM ranked_chapters WHERE rn = 1
      ORDER BY last_read_time DESC
      LIMIT ? OFFSET ?
    ''';

    final result = await _database!.customSelect(
      query,
      variables: [
        Variable<int>(limit),
        Variable<int>(offset),
      ],
    ).get();

    return result.map((row) {
      return ReadingProgress(
        mangaId: row.read<String>('manga_id'),
        chapterId: row.read<String>('chapter_id'),
        chapterTitle: row.read<String>('title'),
        chapterNumber: row.read<int>('number'),
        currentPage: row.read<int>('current_page'),
        lastReadTime: row.read<DateTime>('last_read_time'),
        totalPages: row.read<int>('total_pages'),
        readingPercentage: row.read<double>('reading_percentage'),
        isMarkedAsRead: row.read<bool>('is_marked_as_read'),
        readingDuration: row.read<int>('reading_duration'),
      );
    }).toList();
  }

  /// 获取总的历史记录数量
  Future<int> getTotalHistoryCount() async {
    await init();
    final count = await _database!.chapterProgresses.count().get();
    return count.first;
  }

  /// 获取漫画进度信息
  Future<MangaProgress?> getMangaProgress(String mangaId) async {
    await init();

    final mangaQuery = _database!.select(_database!.mangaProgresses)
      ..where((tbl) => tbl.mangaId.equals(mangaId));
    final mangaProgressList = await mangaQuery.get();

    return mangaProgressList.isNotEmpty ? mangaProgressList.first : null;
  }

  @override
  Future<bool> hasProgress(String mangaId) async {
    await init();

    final chapterQuery = _database!.select(_database!.chapterProgresses)
      ..where((tbl) => tbl.mangaId.equals(mangaId));
    final chapters = await chapterQuery.get();

    return chapters.isNotEmpty;
  }

  /// 更新阅读时长
  Future<void> updateReadingDuration({
    required String chapterId,
    required int durationSeconds,
  }) async {
    await init();

    final chapterQuery = _database!.select(_database!.chapterProgresses)
      ..where((tbl) => tbl.chapterId.equals(chapterId));
    final chapterProgressList = await chapterQuery.get();

    if (chapterProgressList.isNotEmpty) {
      final chapterProgress = chapterProgressList.first;
      await (_database!.update(_database!.chapterProgresses)
            ..where((tbl) => tbl.id.equals(chapterProgress.id)))
          .write(
        ChapterProgressesCompanion(
          readingDuration: Value(durationSeconds),
        ),
      );
    }
  }

  /// 清除所有阅读历史记录
  Future<void> clearAllHistory() async {
    await init();

    // 删除所有章节进度记录
    await _database!.delete(_database!.chapterProgresses).go();

    // 删除所有漫画进度记录
    await _database!.delete(_database!.mangaProgresses).go();
  }

  /// 关闭数据库
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}