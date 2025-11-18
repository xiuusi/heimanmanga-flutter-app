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

/// 数据库定义
@DriftDatabase(tables: [MangaProgresses, ChapterProgresses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // 添加 readingDuration 字段到 ChapterProgresses 表
        await migrator.addColumn(chapterProgresses, chapterProgresses.readingDuration);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'reading_progress.db'));
    return NativeDatabase(file);
  });
}