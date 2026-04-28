import 'package:drift/drift.dart';
import '../models/drift_models.dart';
import 'dart:async';

class FavoritesService {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  AppDatabase? _database;

  Future<void> _ensureDb() async {
    _database ??= AppDatabase();
  }

  Future<bool> isFavorite(String mangaId) async {
    await _ensureDb();
    final query = _database!.select(_database!.favorites)
      ..where((tbl) => tbl.mangaId.equals(mangaId));
    final result = await query.get();
    return result.isNotEmpty;
  }

  Future<void> addFavorite({
    required String mangaId,
    required String title,
    required String author,
    String? coverPath,
  }) async {
    await _ensureDb();
    final existing = await isFavorite(mangaId);
    if (existing) return;

    await _database!.into(_database!.favorites).insert(
      FavoritesCompanion.insert(
        mangaId: mangaId,
        title: title,
        author: author,
        coverPath: coverPath != null ? Value(coverPath) : const Value.absent(),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> removeFavorite(String mangaId) async {
    await _ensureDb();
    await (_database!.delete(_database!.favorites)
          ..where((tbl) => tbl.mangaId.equals(mangaId)))
        .go();
  }

  Future<List<FavoriteItem>> getFavorites({
    int offset = 0,
    int limit = 20,
  }) async {
    await _ensureDb();
    final query = _database!.select(_database!.favorites)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
      ..limit(limit, offset: offset);
    return query.get();
  }

  Future<int> getFavoriteCount() async {
    await _ensureDb();
    final count = await _database!.favorites.count().get();
    return count.first;
  }
}
