import 'package:flutter/material.dart';
import '../models/drift_models.dart';
import '../models/manga.dart';
import '../services/favorites_service.dart';
import 'manga_detail_page.dart';
import 'page_transitions.dart';
import 'manga_list_page.dart';
import 'loading_animations_simplified.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FavoritesService _favoritesService = FavoritesService();
  List<FavoriteItem> _favorites = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasReachedEnd = false;
  static const int _pageSize = 20;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
    }

    final items = await _favoritesService.getFavorites(
      offset: loadMore ? _offset : 0,
      limit: _pageSize,
    );

    if (mounted) {
      setState(() {
        if (loadMore) {
          _favorites.addAll(items);
        } else {
          _favorites = items;
        }
        _offset = _favorites.length;
        _hasReachedEnd = items.length < _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _removeFavorite(String mangaId) async {
    await _favoritesService.removeFavorite(mangaId);
    if (mounted) {
      setState(() {
        _favorites.removeWhere((f) => f.mangaId == mangaId);
        _offset = _favorites.length;
      });
    }
  }

  void refresh() {
    _offset = 0;
    _favorites = [];
    _hasReachedEnd = false;
    _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isLoading && _favorites.isEmpty)
          Expanded(
            child: Center(
              child: LoadingAnimations.mangaGridSkeleton(
                count: 6,
                maxCrossAxisExtent: 200,
              ),
            ),
          )
        else if (_favorites.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '还没有收藏任何漫画',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '在漫画详情页点击收藏按钮添加',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification &&
                    notification.metrics.extentAfter < 200 &&
                    !_isLoadingMore &&
                    !_hasReachedEnd) {
                  _loadFavorites(loadMore: true);
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  childAspectRatio: 2 / 3.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _favorites.length,
                itemBuilder: (context, index) {
                  final item = _favorites[index];
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final manga = _favoriteToManga(item);
                          await Navigator.push(
                            context,
                            PageTransitions.customPageRoute(
                              child: MangaDetailPage(manga: manga),
                              transitionBuilder: PageTransitions.slideTransition,
                            ),
                          );
                          refresh();
                        },
                        child: AbsorbPointer(
                          child: MangaCardWidget(
                            manga: _favoriteToManga(item),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeFavorite(item.mangaId),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Manga _favoriteToManga(FavoriteItem item) {
    return Manga(
      id: item.mangaId,
      title: item.title,
      author: item.author,
      description: '',
      coverPath: item.coverPath ?? '',
      filePath: '',
      fileName: '',
      fileSize: 0,
      uploadTime: '',
      chapters: [],
      tags: [],
    );
  }
}
