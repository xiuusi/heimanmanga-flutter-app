import 'package:drift/drift.dart';
import '../models/drift_models.dart';
import '../models/manga.dart';
import 'reading_progress_service.dart';

/// Drift持久化存储管理器（兼容 drift 2.15.0）
class DriftReadingProgressManager implements ReadingProgressManager {
  AppDatabase? _database;

  @override
  Future<void> init() async {
    _database ??= AppDatabase.instance;
  }

  @override
  Future<void> saveProgress({
    required Manga manga,
    required Chapter chapter,
    required int currentPage,
    required int totalPages,
  }) async {
    await init();

    // 原子 upsert：并发保存（5 秒定时器 + 翻页 + dispose）时不再有
    // SELECT-then-INSERT 竞态，也不会因 UNIQUE(manga_id) 冲突而抛异常（P2-3）。
    // 注意：drift 默认的冲突目标只是主键 id，唯一键必须显式指定。
    final mangaProgress = MangaProgressesCompanion.insert(
      mangaId: manga.id,
      title: manga.title,
      author: manga.author,
      coverPath: Value(manga.coverPath),
      lastReadTime: DateTime.now(),
    );
    await _database!.into(_database!.mangaProgresses).insert(
      mangaProgress,
      onConflict: DoUpdate(
        (_) => mangaProgress,
        target: [_database!.mangaProgresses.mangaId],
      ),
    );

    // 不携带 isMarkedAsRead：冲突更新时只写这些列，保留原有的已阅读标记
    final chapterProgress = ChapterProgressesCompanion.insert(
      chapterId: chapter.id,
      mangaId: manga.id,
      title: chapter.title,
      number: chapter.number,
      currentPage: currentPage,
      totalPages: totalPages,
      readingPercentage: ReadingProgress.calculatePercentage(currentPage, totalPages),
      lastReadTime: DateTime.now(),
    );
    await _database!.into(_database!.chapterProgresses).insert(
      chapterProgress,
      onConflict: DoUpdate(
        (_) => chapterProgress,
        target: [_database!.chapterProgresses.chapterId],
      ),
    );
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
  Future<Map<String, ReadingProgress>> getProgressForChapters(
    String mangaId,
    List<String> chapterIds,
  ) async {
    await init();

    if (chapterIds.isEmpty) return {};

    // 一次查询取回该漫画下所有目标章节的进度，避免详情页逐章查询的 N+1（P2-20）
    final query = _database!.select(_database!.chapterProgresses)
      ..where((tbl) => tbl.mangaId.equals(mangaId) & tbl.chapterId.isIn(chapterIds));
    final chapterProgressList = await query.get();

    final result = <String, ReadingProgress>{};
    for (final chapterProgress in chapterProgressList) {
      result[chapterProgress.chapterId] = ReadingProgress(
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
    return result;
  }

  @override
  Future<void> markChapterAsRead({
    required String mangaId,
    required String chapterId,
    required bool isRead,
  }) async {
    await init();

    // 放在事务里：UPDATE 与"无记录时补插"原子完成，并发下不会因
    // UNIQUE(chapter_id) 冲突而失败（P2-3）
    await _database!.transaction(() async {
      final updated = await (_database!.update(_database!.chapterProgresses)
            ..where((tbl) => tbl.chapterId.equals(chapterId)))
          .write(
        ChapterProgressesCompanion(
          isMarkedAsRead: Value(isRead),
          lastReadTime: Value(DateTime.now()),
        ),
      );

      // 没有现成进度记录时：
      // - 取消已读（isRead == false）：无需插入任何记录（P2-3b）
      // - 标记已读：插入一条"零进度"占位记录，不再伪造 100% 已读的幽灵行
      if (updated == 0 && isRead) {
        await _database!.into(_database!.chapterProgresses).insert(
          ChapterProgressesCompanion.insert(
            chapterId: chapterId,
            mangaId: mangaId,
            title: 'Unknown',
            number: 0,
            currentPage: 0,
            totalPages: 0,
            readingPercentage: 0.0,
            isMarkedAsRead: const Value(true),
            lastReadTime: DateTime.now(),
          ),
        );
      }
    });
  }

  @override
  Future<Map<String, dynamic>> getReadingStats() async {
    await init();

    final mangaCount = await _database!.mangaProgresses.count().get();

    final allChaptersQuery = _database!.select(_database!.chapterProgresses);
    final allChapters = await allChaptersQuery.get();

    // 语义说明：这是"各章节最后到达页码之和"（0-based 页码 + 1），
    // 并非严格意义的已读页数（未开始的章节也会计 1 页）。
    // 'totalPages' 键名保留以兼容设置页调用方；'totalPagesReached' 为语义准确的新键名。
    final reachedPageSum = allChapters.fold(0, (sum, chapter) => sum + chapter.currentPage + 1);
    final averageProgress = allChapters.isEmpty
        ? 0.0
        : allChapters.map((chapter) => chapter.readingPercentage).reduce((a, b) => a + b) / allChapters.length;

    return {
      'totalManga': mangaCount,
      'totalPages': reachedPageSum,
      'totalPagesReached': reachedPageSum,
      'averageProgress': averageProgress,
      'lastReadTime': null,
    };
  }

  @override
  Future<List<ReadingProgress>> getRecentRead({int limit = 10, int offset = 0}) async {
    await init();

    // 使用窗口函数按漫画分组，取每个漫画的最新章节记录
    // 按最后阅读时间降序排列，如果时间相同则按章节号降序（取最新章节）
    const query = '''
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

    await _database!.delete(_database!.chapterProgresses).go();
    await _database!.delete(_database!.mangaProgresses).go();
  }

  /// 删除单条漫画阅读历史
  @override
  Future<void> deleteMangaProgress(String mangaId) async {
    await init();
    await (_database!.delete(_database!.chapterProgresses)
          ..where((tbl) => tbl.mangaId.equals(mangaId)))
        .go();
    await (_database!.delete(_database!.mangaProgresses)
          ..where((tbl) => tbl.mangaId.equals(mangaId)))
        .go();
  }

  /// 关闭数据库
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}