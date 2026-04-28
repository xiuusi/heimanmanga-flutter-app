import 'package:flutter_test/flutter_test.dart';
import 'package:heimanmanga/models/manga.dart';
import 'package:heimanmanga/utils/parsers.dart';
import 'package:heimanmanga/utils/tag_utils.dart';

void main() {
  group('Manga.fromJson', () {
    test('parses basic manga fields', () {
      final json = {
        'id': 'm123',
        'title': 'Test Manga',
        'author': 'Test Author',
        'description': 'A test manga.',
        'cover_path': '/covers/m123.jpg',
        'file_path': '/files/m123.zip',
        'file_name': 'test.zip',
        'file_size': 1024,
        'upload_time': '2025-01-01T00:00:00Z',
        'chapters': <Map<String, dynamic>>[],
        'tags': <Map<String, dynamic>>[],
      };

      final manga = Manga.fromJson(json);

      expect(manga.id, 'm123');
      expect(manga.title, 'Test Manga');
      expect(manga.author, 'Test Author');
      expect(manga.description, 'A test manga.');
      expect(manga.coverPath, '/covers/m123.jpg');
      expect(manga.fileSize, 1024);
      expect(manga.chapters, isEmpty);
      expect(manga.tags, isEmpty);
    });

    test('parses manga with camelCase covers', () {
      final json = {
        'id': 'm456',
        'title': 'CamelCase',
        'author': 'Test',
        'description': '',
        'coverPath': '/covers/m456.jpg',
        'filePath': '',
        'fileName': '',
        'fileSize': 0,
        'uploadTime': '',
        'chapters': <Map<String, dynamic>>[],
        'tags': <Map<String, dynamic>>[],
      };

      final manga = Manga.fromJson(json);

      expect(manga.id, 'm456');
      expect(manga.coverPath, '/covers/m456.jpg');
    });

    test('parses nested chapters', () {
      final json = {
        'id': 'm789',
        'title': 'With Chapters',
        'author': 'Test',
        'description': '',
        'cover_path': '',
        'file_path': '',
        'file_name': '',
        'file_size': 0,
        'upload_time': '',
        'chapters': [
          {
            'id': 'ch1',
            'manga_id': 'm789',
            'title': 'Chapter 1',
            'number': 1,
            'file_path': '/files/ch1.zip',
            'file_name': 'ch1.zip',
            'file_size': 512,
            'image_list': ['001.jpg', '002.jpg'],
            'image_id_map': {'001.jpg': 'img1', '002.jpg': 'img2'},
            'total_pages': 2,
          },
        ],
        'tags': <Map<String, dynamic>>[],
      };

      final manga = Manga.fromJson(json);

      expect(manga.chapters, hasLength(1));
      expect(manga.chapters[0].id, 'ch1');
      expect(manga.chapters[0].title, 'Chapter 1');
      expect(manga.chapters[0].number, 1);
      expect(manga.chapters[0].imageList, ['001.jpg', '002.jpg']);
      expect(manga.chapters[0].totalPages, 2);
    });
  });

  group('DataParsers', () {
    test('parseString returns default for null', () {
      expect(DataParsers.parseString(null), '');
      expect(DataParsers.parseString('hello'), 'hello');
    });

    test('parseIntWithDefault handles various inputs', () {
      expect(DataParsers.parseIntWithDefault(null), 0);
      expect(DataParsers.parseIntWithDefault(42), 42);
      expect(DataParsers.parseIntWithDefault('99'), 99);
      expect(DataParsers.parseIntWithDefault(42.7), 42);
    });

    test('parseList returns null for non-list', () {
      expect(DataParsers.parseList(null), null);
      expect(DataParsers.parseList('not a list'), null);
      expect(DataParsers.parseList(123), null);
    });

    test('parseList returns list for valid input', () {
      final data = [
        {'a': 1},
        {'b': 2},
      ];
      final result = DataParsers.parseList(data);
      expect(result, isNotNull);
      expect(result, hasLength(2));
    });
  });

  group('TagUtils', () {
    test('namespaceNameFromId maps correctly', () {
      expect(TagUtils.namespaceNameFromId(1), 'type');
      expect(TagUtils.namespaceNameFromId(2), 'artist');
      expect(TagUtils.namespaceNameFromId(3), 'character');
      expect(TagUtils.namespaceNameFromId(4), 'main');
      expect(TagUtils.namespaceNameFromId(5), 'sub');
      expect(TagUtils.namespaceNameFromId(99), 'unknown');
    });

    test('tag colors return non-null values', () {
      final namespaces = ['type', 'artist', 'character', 'main', 'sub'];
      for (final ns in namespaces) {
        expect(
          TagUtils.tagChipBackgroundColor(ns),
          isNotNull,
          reason: 'background color for $ns',
        );
        expect(
          TagUtils.tagChipTextColor(ns),
          isNotNull,
          reason: 'text color for $ns',
        );
      }
      for (final ns in namespaces) {
        if (ns != 'character') {
          expect(
            TagUtils.detailTagColor(ns),
            isNotNull,
            reason: 'detail color for $ns',
          );
        }
      }
    });
  });
}
