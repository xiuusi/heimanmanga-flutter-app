import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import 'manga_detail_page.dart';

enum SearchType { title, author, tag }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  SearchType _searchType = SearchType.title;

  List<Manga> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _currentPage = 1;
  bool _isLoadingMore = false;

  late AnimationController _heroAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _heroAnimationController,
      curve: Curves.easeInOut,
    ));

    _heroAnimationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _heroAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _searchResults.isNotEmpty) {
      _loadMoreResults();
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasSearched = true;
    });

    try {
      final results = await MangaApiService.searchManga(
        query,
        page: _currentPage,
        searchType: _searchType.name,
      );

      setState(() {
        _searchResults = results.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('搜索失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    try {
      final results = await MangaApiService.searchManga(
        _searchController.text.trim(),
        page: _currentPage,
        searchType: _searchType.name,
      );

      setState(() {
        _searchResults.addAll(results.data);
        _isLoadingMore = false;
      });
    } catch (e) {
      _currentPage--; // 回滚页码
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 搜索英雄区
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFF6B6B),
                    const Color(0xFFFF6B6B).withOpacity(0.8),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        const Text(
                          '✨ 搜本站',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '输入关键词，或作者',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // 搜索框
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onSubmitted: (_) => _performSearch(),
                            decoration: InputDecoration(
                              hintText: '输入关键词...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchResults.clear();
                                          _hasSearched = false;
                                        });
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 20,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 搜索类型选择
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: SearchType.values.map((type) {
                            final isSelected = _searchType == type;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Text(_getSearchTypeLabel(type)),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _searchType = type;
                                    });
                                    // 如果已有搜索结果，重新搜索
                                    if (_hasSearched && _searchController.text.isNotEmpty) {
                                      _performSearch();
                                    }
                                  }
                                },
                                backgroundColor: Colors.white.withOpacity(0.3),
                                selectedColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: isSelected ? const Color(0xFFFF6B6B) : Colors.white,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 搜索结果区域
          if (_hasSearched) ...[
            // 结果标题
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Text(
                      '搜索结果',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${_searchResults.length}本)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 搜索结果网格
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(50),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                    ),
                  ),
                ),
              )
            else if (_searchResults.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(50),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '🌌 宇宙中暂时没有发现你要找的漫画',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '换个关键词试试吧！',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 2 / 3.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _searchResults.length && _isLoadingMore) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                            ),
                          ),
                        );
                      }

                      if (index >= _searchResults.length) {
                        return null;
                      }

                      return _buildSearchResultCard(_searchResults[index], index);
                    },
                    childCount: _searchResults.length + (_isLoadingMore ? 1 : 0),
                  ),
                ),
              ),

            // 底部间距
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(Manga manga, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MangaDetailPage(manga: manga),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: CachedNetworkImage(
                          imageUrl: MangaApiService.getCoverUrl(manga.id),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                          httpHeaders: MangaApiService.userAgent.isNotEmpty
                              ? {'User-Agent': MangaApiService.userAgent}
                              : null,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            manga.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            manga.author,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF757575),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getSearchTypeLabel(SearchType type) {
    switch (type) {
      case SearchType.title:
        return '标题';
      case SearchType.author:
        return '作者';
      case SearchType.tag:
        return '标签';
    }
  }
}