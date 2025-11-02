// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_models.dart';

// ignore_for_file: type=lint
class $MangaProgressesTable extends MangaProgresses
    with TableInfo<$MangaProgressesTable, MangaProgress> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MangaProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _mangaIdMeta =
      const VerificationMeta('mangaId');
  @override
  late final GeneratedColumn<String> mangaId = GeneratedColumn<String>(
      'manga_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _coverPathMeta =
      const VerificationMeta('coverPath');
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
      'cover_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastReadTimeMeta =
      const VerificationMeta('lastReadTime');
  @override
  late final GeneratedColumn<DateTime> lastReadTime = GeneratedColumn<DateTime>(
      'last_read_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, mangaId, title, author, coverPath, lastReadTime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manga_progresses';
  @override
  VerificationContext validateIntegrity(Insertable<MangaProgress> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('manga_id')) {
      context.handle(_mangaIdMeta,
          mangaId.isAcceptableOrUnknown(data['manga_id']!, _mangaIdMeta));
    } else if (isInserting) {
      context.missing(_mangaIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(_coverPathMeta,
          coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta));
    }
    if (data.containsKey('last_read_time')) {
      context.handle(
          _lastReadTimeMeta,
          lastReadTime.isAcceptableOrUnknown(
              data['last_read_time']!, _lastReadTimeMeta));
    } else if (isInserting) {
      context.missing(_lastReadTimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {mangaId},
      ];
  @override
  MangaProgress map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MangaProgress(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      mangaId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}manga_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      coverPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_path']),
      lastReadTime: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_read_time'])!,
    );
  }

  @override
  $MangaProgressesTable createAlias(String alias) {
    return $MangaProgressesTable(attachedDatabase, alias);
  }
}

class MangaProgress extends DataClass implements Insertable<MangaProgress> {
  /// 主键
  final int id;

  /// 漫画ID
  final String mangaId;

  /// 漫画标题
  final String title;

  /// 作者
  final String author;

  /// 封面路径
  final String? coverPath;

  /// 最后阅读时间
  final DateTime lastReadTime;
  const MangaProgress(
      {required this.id,
      required this.mangaId,
      required this.title,
      required this.author,
      this.coverPath,
      required this.lastReadTime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['manga_id'] = Variable<String>(mangaId);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['last_read_time'] = Variable<DateTime>(lastReadTime);
    return map;
  }

  MangaProgressesCompanion toCompanion(bool nullToAbsent) {
    return MangaProgressesCompanion(
      id: Value(id),
      mangaId: Value(mangaId),
      title: Value(title),
      author: Value(author),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      lastReadTime: Value(lastReadTime),
    );
  }

  factory MangaProgress.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MangaProgress(
      id: serializer.fromJson<int>(json['id']),
      mangaId: serializer.fromJson<String>(json['mangaId']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      lastReadTime: serializer.fromJson<DateTime>(json['lastReadTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mangaId': serializer.toJson<String>(mangaId),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'coverPath': serializer.toJson<String?>(coverPath),
      'lastReadTime': serializer.toJson<DateTime>(lastReadTime),
    };
  }

  MangaProgress copyWith(
          {int? id,
          String? mangaId,
          String? title,
          String? author,
          Value<String?> coverPath = const Value.absent(),
          DateTime? lastReadTime}) =>
      MangaProgress(
        id: id ?? this.id,
        mangaId: mangaId ?? this.mangaId,
        title: title ?? this.title,
        author: author ?? this.author,
        coverPath: coverPath.present ? coverPath.value : this.coverPath,
        lastReadTime: lastReadTime ?? this.lastReadTime,
      );
  @override
  String toString() {
    return (StringBuffer('MangaProgress(')
          ..write('id: $id, ')
          ..write('mangaId: $mangaId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverPath: $coverPath, ')
          ..write('lastReadTime: $lastReadTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, mangaId, title, author, coverPath, lastReadTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MangaProgress &&
          other.id == this.id &&
          other.mangaId == this.mangaId &&
          other.title == this.title &&
          other.author == this.author &&
          other.coverPath == this.coverPath &&
          other.lastReadTime == this.lastReadTime);
}

class MangaProgressesCompanion extends UpdateCompanion<MangaProgress> {
  final Value<int> id;
  final Value<String> mangaId;
  final Value<String> title;
  final Value<String> author;
  final Value<String?> coverPath;
  final Value<DateTime> lastReadTime;
  const MangaProgressesCompanion({
    this.id = const Value.absent(),
    this.mangaId = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.lastReadTime = const Value.absent(),
  });
  MangaProgressesCompanion.insert({
    this.id = const Value.absent(),
    required String mangaId,
    required String title,
    required String author,
    this.coverPath = const Value.absent(),
    required DateTime lastReadTime,
  })  : mangaId = Value(mangaId),
        title = Value(title),
        author = Value(author),
        lastReadTime = Value(lastReadTime);
  static Insertable<MangaProgress> custom({
    Expression<int>? id,
    Expression<String>? mangaId,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? coverPath,
    Expression<DateTime>? lastReadTime,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mangaId != null) 'manga_id': mangaId,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (coverPath != null) 'cover_path': coverPath,
      if (lastReadTime != null) 'last_read_time': lastReadTime,
    });
  }

  MangaProgressesCompanion copyWith(
      {Value<int>? id,
      Value<String>? mangaId,
      Value<String>? title,
      Value<String>? author,
      Value<String?>? coverPath,
      Value<DateTime>? lastReadTime}) {
    return MangaProgressesCompanion(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      lastReadTime: lastReadTime ?? this.lastReadTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mangaId.present) {
      map['manga_id'] = Variable<String>(mangaId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (lastReadTime.present) {
      map['last_read_time'] = Variable<DateTime>(lastReadTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MangaProgressesCompanion(')
          ..write('id: $id, ')
          ..write('mangaId: $mangaId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverPath: $coverPath, ')
          ..write('lastReadTime: $lastReadTime')
          ..write(')'))
        .toString();
  }
}

class $ChapterProgressesTable extends ChapterProgresses
    with TableInfo<$ChapterProgressesTable, ChapterProgress> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChapterProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _chapterIdMeta =
      const VerificationMeta('chapterId');
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
      'chapter_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mangaIdMeta =
      const VerificationMeta('mangaId');
  @override
  late final GeneratedColumn<String> mangaId = GeneratedColumn<String>(
      'manga_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
      'number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currentPageMeta =
      const VerificationMeta('currentPage');
  @override
  late final GeneratedColumn<int> currentPage = GeneratedColumn<int>(
      'current_page', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _totalPagesMeta =
      const VerificationMeta('totalPages');
  @override
  late final GeneratedColumn<int> totalPages = GeneratedColumn<int>(
      'total_pages', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _readingPercentageMeta =
      const VerificationMeta('readingPercentage');
  @override
  late final GeneratedColumn<double> readingPercentage =
      GeneratedColumn<double>('reading_percentage', aliasedName, false,
          type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _isMarkedAsReadMeta =
      const VerificationMeta('isMarkedAsRead');
  @override
  late final GeneratedColumn<bool> isMarkedAsRead = GeneratedColumn<bool>(
      'is_marked_as_read', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_marked_as_read" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lastReadTimeMeta =
      const VerificationMeta('lastReadTime');
  @override
  late final GeneratedColumn<DateTime> lastReadTime = GeneratedColumn<DateTime>(
      'last_read_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        chapterId,
        mangaId,
        title,
        number,
        currentPage,
        totalPages,
        readingPercentage,
        isMarkedAsRead,
        lastReadTime
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapter_progresses';
  @override
  VerificationContext validateIntegrity(Insertable<ChapterProgress> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('chapter_id')) {
      context.handle(_chapterIdMeta,
          chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta));
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('manga_id')) {
      context.handle(_mangaIdMeta,
          mangaId.isAcceptableOrUnknown(data['manga_id']!, _mangaIdMeta));
    } else if (isInserting) {
      context.missing(_mangaIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('number')) {
      context.handle(_numberMeta,
          number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('current_page')) {
      context.handle(
          _currentPageMeta,
          currentPage.isAcceptableOrUnknown(
              data['current_page']!, _currentPageMeta));
    } else if (isInserting) {
      context.missing(_currentPageMeta);
    }
    if (data.containsKey('total_pages')) {
      context.handle(
          _totalPagesMeta,
          totalPages.isAcceptableOrUnknown(
              data['total_pages']!, _totalPagesMeta));
    } else if (isInserting) {
      context.missing(_totalPagesMeta);
    }
    if (data.containsKey('reading_percentage')) {
      context.handle(
          _readingPercentageMeta,
          readingPercentage.isAcceptableOrUnknown(
              data['reading_percentage']!, _readingPercentageMeta));
    } else if (isInserting) {
      context.missing(_readingPercentageMeta);
    }
    if (data.containsKey('is_marked_as_read')) {
      context.handle(
          _isMarkedAsReadMeta,
          isMarkedAsRead.isAcceptableOrUnknown(
              data['is_marked_as_read']!, _isMarkedAsReadMeta));
    }
    if (data.containsKey('last_read_time')) {
      context.handle(
          _lastReadTimeMeta,
          lastReadTime.isAcceptableOrUnknown(
              data['last_read_time']!, _lastReadTimeMeta));
    } else if (isInserting) {
      context.missing(_lastReadTimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {chapterId},
      ];
  @override
  ChapterProgress map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterProgress(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      chapterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chapter_id'])!,
      mangaId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}manga_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      number: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}number'])!,
      currentPage: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_page'])!,
      totalPages: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_pages'])!,
      readingPercentage: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}reading_percentage'])!,
      isMarkedAsRead: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_marked_as_read'])!,
      lastReadTime: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_read_time'])!,
    );
  }

  @override
  $ChapterProgressesTable createAlias(String alias) {
    return $ChapterProgressesTable(attachedDatabase, alias);
  }
}

class ChapterProgress extends DataClass implements Insertable<ChapterProgress> {
  /// 主键
  final int id;

  /// 章节ID
  final String chapterId;

  /// 漫画ID
  final String mangaId;

  /// 章节标题
  final String title;

  /// 章节编号
  final int number;

  /// 当前页码
  final int currentPage;

  /// 总页数
  final int totalPages;

  /// 阅读百分比
  final double readingPercentage;

  /// 已阅读标记
  final bool isMarkedAsRead;

  /// 最后阅读时间
  final DateTime lastReadTime;
  const ChapterProgress(
      {required this.id,
      required this.chapterId,
      required this.mangaId,
      required this.title,
      required this.number,
      required this.currentPage,
      required this.totalPages,
      required this.readingPercentage,
      required this.isMarkedAsRead,
      required this.lastReadTime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['chapter_id'] = Variable<String>(chapterId);
    map['manga_id'] = Variable<String>(mangaId);
    map['title'] = Variable<String>(title);
    map['number'] = Variable<int>(number);
    map['current_page'] = Variable<int>(currentPage);
    map['total_pages'] = Variable<int>(totalPages);
    map['reading_percentage'] = Variable<double>(readingPercentage);
    map['is_marked_as_read'] = Variable<bool>(isMarkedAsRead);
    map['last_read_time'] = Variable<DateTime>(lastReadTime);
    return map;
  }

  ChapterProgressesCompanion toCompanion(bool nullToAbsent) {
    return ChapterProgressesCompanion(
      id: Value(id),
      chapterId: Value(chapterId),
      mangaId: Value(mangaId),
      title: Value(title),
      number: Value(number),
      currentPage: Value(currentPage),
      totalPages: Value(totalPages),
      readingPercentage: Value(readingPercentage),
      isMarkedAsRead: Value(isMarkedAsRead),
      lastReadTime: Value(lastReadTime),
    );
  }

  factory ChapterProgress.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterProgress(
      id: serializer.fromJson<int>(json['id']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      mangaId: serializer.fromJson<String>(json['mangaId']),
      title: serializer.fromJson<String>(json['title']),
      number: serializer.fromJson<int>(json['number']),
      currentPage: serializer.fromJson<int>(json['currentPage']),
      totalPages: serializer.fromJson<int>(json['totalPages']),
      readingPercentage: serializer.fromJson<double>(json['readingPercentage']),
      isMarkedAsRead: serializer.fromJson<bool>(json['isMarkedAsRead']),
      lastReadTime: serializer.fromJson<DateTime>(json['lastReadTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'chapterId': serializer.toJson<String>(chapterId),
      'mangaId': serializer.toJson<String>(mangaId),
      'title': serializer.toJson<String>(title),
      'number': serializer.toJson<int>(number),
      'currentPage': serializer.toJson<int>(currentPage),
      'totalPages': serializer.toJson<int>(totalPages),
      'readingPercentage': serializer.toJson<double>(readingPercentage),
      'isMarkedAsRead': serializer.toJson<bool>(isMarkedAsRead),
      'lastReadTime': serializer.toJson<DateTime>(lastReadTime),
    };
  }

  ChapterProgress copyWith(
          {int? id,
          String? chapterId,
          String? mangaId,
          String? title,
          int? number,
          int? currentPage,
          int? totalPages,
          double? readingPercentage,
          bool? isMarkedAsRead,
          DateTime? lastReadTime}) =>
      ChapterProgress(
        id: id ?? this.id,
        chapterId: chapterId ?? this.chapterId,
        mangaId: mangaId ?? this.mangaId,
        title: title ?? this.title,
        number: number ?? this.number,
        currentPage: currentPage ?? this.currentPage,
        totalPages: totalPages ?? this.totalPages,
        readingPercentage: readingPercentage ?? this.readingPercentage,
        isMarkedAsRead: isMarkedAsRead ?? this.isMarkedAsRead,
        lastReadTime: lastReadTime ?? this.lastReadTime,
      );
  @override
  String toString() {
    return (StringBuffer('ChapterProgress(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('mangaId: $mangaId, ')
          ..write('title: $title, ')
          ..write('number: $number, ')
          ..write('currentPage: $currentPage, ')
          ..write('totalPages: $totalPages, ')
          ..write('readingPercentage: $readingPercentage, ')
          ..write('isMarkedAsRead: $isMarkedAsRead, ')
          ..write('lastReadTime: $lastReadTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, chapterId, mangaId, title, number,
      currentPage, totalPages, readingPercentage, isMarkedAsRead, lastReadTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterProgress &&
          other.id == this.id &&
          other.chapterId == this.chapterId &&
          other.mangaId == this.mangaId &&
          other.title == this.title &&
          other.number == this.number &&
          other.currentPage == this.currentPage &&
          other.totalPages == this.totalPages &&
          other.readingPercentage == this.readingPercentage &&
          other.isMarkedAsRead == this.isMarkedAsRead &&
          other.lastReadTime == this.lastReadTime);
}

class ChapterProgressesCompanion extends UpdateCompanion<ChapterProgress> {
  final Value<int> id;
  final Value<String> chapterId;
  final Value<String> mangaId;
  final Value<String> title;
  final Value<int> number;
  final Value<int> currentPage;
  final Value<int> totalPages;
  final Value<double> readingPercentage;
  final Value<bool> isMarkedAsRead;
  final Value<DateTime> lastReadTime;
  const ChapterProgressesCompanion({
    this.id = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.mangaId = const Value.absent(),
    this.title = const Value.absent(),
    this.number = const Value.absent(),
    this.currentPage = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.readingPercentage = const Value.absent(),
    this.isMarkedAsRead = const Value.absent(),
    this.lastReadTime = const Value.absent(),
  });
  ChapterProgressesCompanion.insert({
    this.id = const Value.absent(),
    required String chapterId,
    required String mangaId,
    required String title,
    required int number,
    required int currentPage,
    required int totalPages,
    required double readingPercentage,
    this.isMarkedAsRead = const Value.absent(),
    required DateTime lastReadTime,
  })  : chapterId = Value(chapterId),
        mangaId = Value(mangaId),
        title = Value(title),
        number = Value(number),
        currentPage = Value(currentPage),
        totalPages = Value(totalPages),
        readingPercentage = Value(readingPercentage),
        lastReadTime = Value(lastReadTime);
  static Insertable<ChapterProgress> custom({
    Expression<int>? id,
    Expression<String>? chapterId,
    Expression<String>? mangaId,
    Expression<String>? title,
    Expression<int>? number,
    Expression<int>? currentPage,
    Expression<int>? totalPages,
    Expression<double>? readingPercentage,
    Expression<bool>? isMarkedAsRead,
    Expression<DateTime>? lastReadTime,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chapterId != null) 'chapter_id': chapterId,
      if (mangaId != null) 'manga_id': mangaId,
      if (title != null) 'title': title,
      if (number != null) 'number': number,
      if (currentPage != null) 'current_page': currentPage,
      if (totalPages != null) 'total_pages': totalPages,
      if (readingPercentage != null) 'reading_percentage': readingPercentage,
      if (isMarkedAsRead != null) 'is_marked_as_read': isMarkedAsRead,
      if (lastReadTime != null) 'last_read_time': lastReadTime,
    });
  }

  ChapterProgressesCompanion copyWith(
      {Value<int>? id,
      Value<String>? chapterId,
      Value<String>? mangaId,
      Value<String>? title,
      Value<int>? number,
      Value<int>? currentPage,
      Value<int>? totalPages,
      Value<double>? readingPercentage,
      Value<bool>? isMarkedAsRead,
      Value<DateTime>? lastReadTime}) {
    return ChapterProgressesCompanion(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      mangaId: mangaId ?? this.mangaId,
      title: title ?? this.title,
      number: number ?? this.number,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      readingPercentage: readingPercentage ?? this.readingPercentage,
      isMarkedAsRead: isMarkedAsRead ?? this.isMarkedAsRead,
      lastReadTime: lastReadTime ?? this.lastReadTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (mangaId.present) {
      map['manga_id'] = Variable<String>(mangaId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (currentPage.present) {
      map['current_page'] = Variable<int>(currentPage.value);
    }
    if (totalPages.present) {
      map['total_pages'] = Variable<int>(totalPages.value);
    }
    if (readingPercentage.present) {
      map['reading_percentage'] = Variable<double>(readingPercentage.value);
    }
    if (isMarkedAsRead.present) {
      map['is_marked_as_read'] = Variable<bool>(isMarkedAsRead.value);
    }
    if (lastReadTime.present) {
      map['last_read_time'] = Variable<DateTime>(lastReadTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChapterProgressesCompanion(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('mangaId: $mangaId, ')
          ..write('title: $title, ')
          ..write('number: $number, ')
          ..write('currentPage: $currentPage, ')
          ..write('totalPages: $totalPages, ')
          ..write('readingPercentage: $readingPercentage, ')
          ..write('isMarkedAsRead: $isMarkedAsRead, ')
          ..write('lastReadTime: $lastReadTime')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $MangaProgressesTable mangaProgresses =
      $MangaProgressesTable(this);
  late final $ChapterProgressesTable chapterProgresses =
      $ChapterProgressesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [mangaProgresses, chapterProgresses];
}
