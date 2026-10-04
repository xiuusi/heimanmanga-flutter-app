import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

part 'drift_models.g.dart';

/// 漫画进度表
@DataClassName('MangaProgress')
class MangaProgresses extends Table {
  /// 主键
  IntColumn get id => integer().autoIncrement()();

  /// 漫画ID
  TextColumn get mangaId => text()();

  /// 漫画标题
  TextColumn get title => text()();

  /// 作者
  TextColumn get author => text()();

  /// 封面路径
  TextColumn get coverPath => text().nullable()();

  /// 最后阅读时间
  DateTimeColumn get lastReadTime => dateTime()();

  /// 唯一索引
  @override
  List<Set<Column>> get uniqueKeys => [{mangaId}];
}

/// 章节进度表
@DataClassName('ChapterProgress')
class ChapterProgresses extends Table {
  /// 主键
  IntColumn get id => integer().autoIncrement()();

  /// 章节ID
  TextColumn get chapterId => text()();

  /// 漫画ID
  TextColumn get mangaId => text()();

  /// 章节标题
  TextColumn get title => text()();

  /// 章节编号
  IntColumn get number => integer()();

  /// 当前页码
  IntColumn get currentPage => integer()();

  /// 总页数
  IntColumn get totalPages => integer()();

  /// 阅读百分比
  RealColumn get readingPercentage => real()();

  /// 已阅读标记
  BoolColumn get isMarkedAsRead => boolean().withDefault(const Constant(false))();

  /// 最后阅读时间
  DateTimeColumn get lastReadTime => dateTime()();

  /// 阅读时长（秒）
  IntColumn get readingDuration => integer().withDefault(const Constant(0))();

  /// 唯一索引
  @override
  List<Set<Column>> get uniqueKeys => [{chapterId}];
}

/// 收藏表
@DataClassName('FavoriteItem')
class Favorites extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get mangaId => text()();

  TextColumn get title => text()();

  TextColumn get author => text()();

  TextColumn get coverPath => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [{mangaId}];
}

/// 数据库定义
@DriftDatabase(tables: [MangaProgresses, ChapterProgresses, Favorites])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());

  /// 进程内唯一实例。
  ///
  /// 每个 [AppDatabase] 都会在同一个 .db 文件上打开一条独立的 SQLite 连接：
  /// 之前"阅读进度"和"收藏"各自 `AppDatabase()`，两条连接并发写会触发
  /// `SQLITE_BUSY: database is locked`，而阅读器侧会把该异常吞掉，
  /// 造成进度静默丢失（P1-3）。改为全局单例后由同一连接串行化写入。
  static AppDatabase? _shared;

  static AppDatabase get instance => _shared ??= AppDatabase._internal();

  /// 关闭共享连接（测试或需要彻底释放时使用）。
  static Future<void> closeShared() async {
    final db = _shared;
    _shared = null;
    await db?.close();
  }

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(chapterProgresses, chapterProgresses.readingDuration);
      }
      if (from < 3) {
        await migrator.createTable(favorites);
      }
    },
  );
}

/// 打开数据库连接。
///
/// - `createInBackground`：SQLite 的打开/查询/提交都放到后台 isolate，
///   避免建表、迁移与每次保存的 fsync 阻塞 UI 线程（P1-5）。
/// - `journal_mode = WAL` + `busy_timeout`：WAL 允许读写并发（默认的
///   delete 日志模式下读写互斥），busy_timeout 让写锁冲突时等待重试而不是
///   立刻抛错（P1-3）。
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'reading_progress.db'));
    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        database.execute('PRAGMA journal_mode = WAL;');
        database.execute('PRAGMA busy_timeout = 5000;');
      },
    );
  });
}