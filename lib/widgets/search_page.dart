import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import 'manga_list_page.dart';

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
  bool _hasReachedEnd = false;

  /// 请求序号：每次新搜索自增，用于丢弃过期响应（P2-15）
  int _searchRequestId = 0;

  /// 单页数量，与 MangaApiService.searchManga 的默认 limit 保持一致
  static const int _pageSize = 21;

  late AnimationController _heroAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 监听输入框文本变化，仅用于刷新清除按钮的显示（P3）
    _searchController.addListener(_onSearchChanged);

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
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _heroAnimationController.dispose();
    super.dispose();
  }

  /// 输入框文本变化时仅刷新清除按钮的显示，不自动触发搜索
  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isLoading &&
        !_hasReachedEnd &&
        _searchResults.isNotEmpty) {
      _loadMoreResults();
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // 新的请求序号：在途的旧搜索/加载更多响应都会被丢弃（P2-15）
    final requestId = ++_searchRequestId;

    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasSearched = true;
      _hasReachedEnd = false;
      _isLoadingMore = false;
    });

    try {
      final results = await MangaApiService.searchManga(
        query,
        page: 1,
        limit: _pageSize,
        searchType: _searchType.name,
      );

      if (requestId != _searchRequestId) return;
      if (!mounted) return;

      setState(() {
        _searchResults = results.data;
        _currentPage = 1;
        _isLoading = false;
        // 返回不足一页，或已达到总页数，则判定到底（P2-14）
        _hasReachedEnd = results.data.length < _pageSize ||
            (results.totalPages > 0 && results.page >= results.totalPages);
      });
    } catch (e) {
      if (requestId != _searchRequestId) return;
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('搜索失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoadingMore || _isLoading || _hasReachedEnd) return;

    final requestId = _searchRequestId;
    final nextPage = _currentPage + 1;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final results = await MangaApiService.searchManga(
        _searchController.text.trim(),
        page: nextPage,
        limit: _pageSize,
        searchType: _searchType.name,
      );

      // 过期响应直接丢弃，避免把旧查询的第二页追加到新列表（P2-15）
      if (requestId != _searchRequestId) return;
      if (!mounted) return;

      setState(() {
        _searchResults.addAll(results.data);
        // 成功后才自增页码，失败时页码保持不变（无需回滚）
        _currentPage = nextPage;
        _isLoadingMore = false;
        _hasReachedEnd = results.data.length < _pageSize ||
            (results.totalPages > 0 && nextPage >= results.totalPages);
      });
    } catch (e) {
      if (requestId != _searchRequestId) return;
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
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
                    primary,
                    primary.withValues(alpha: 0.8),
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
                            // 使用主题表面色，保证暗色模式下文字依然可读（P3）
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
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
                                        // 使在途请求失效，避免旧响应回填已清空的结果
                                        _searchRequestId++;
                                        setState(() {
                                          _searchResults.clear();
                                          _hasSearched = false;
                                          _hasReachedEnd = false;
                                          _isLoadingMore = false;
                                          _currentPage = 1;
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
                                backgroundColor: Colors.white.withValues(alpha: 0.3),
                                selectedColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: isSelected ? primary : Colors.white.withValues(alpha: 0.95),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: isSelected ? 0.1 : 0.4),
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                                side: BorderSide(
                                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
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
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(50),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
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
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(primary),
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
            child: MangaCardWidget(manga: manga),
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