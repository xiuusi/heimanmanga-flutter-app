import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import 'loading_animations_simplified.dart';
import 'manga_list_page.dart';
import 'pagination_widget.dart';

class TagsPage extends StatefulWidget {
  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  List<TagNamespace> _namespaces = [];
  List<TagModel> _allTags = [];
  List<TagModel> _filteredTags = [];
  TagNamespace? _selectedNamespace;
  TagModel? _selectedTag;

  late Future<MangaListResponse> _mangaListFuture;
  int _currentPage = 1;
  final int _pageSize = 20;
  MangaListResponse? _currentMangaResponse;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNamespacesAndTags();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _filterTagsByNamespace(_selectedNamespace);
    } else {
      _searchTags(query);
    }
  }

  Future<void> _loadNamespacesAndTags() async {
    try {
      final results = await Future.wait([
        MangaApiService.getTagNamespaces(),
        MangaApiService.getTags(),
      ]);

      setState(() {
        _namespaces = results[0] as List<TagNamespace>;
        _allTags = results[1] as List<TagModel>;
        _selectedNamespace = _namespaces.isNotEmpty ? _namespaces.first : null;
      });

      _filterTagsByNamespace(_selectedNamespace);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载标签数据失败: $e')),
        );
      }
    }
  }

  Future<void> _searchTags(String query) async {
    if (query.isEmpty) {
      _filterTagsByNamespace(_selectedNamespace);
      return;
    }

    try {
      final searchResults = await MangaApiService.searchTags(query);
      setState(() {
        _filteredTags = searchResults;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索标签失败: $e')),
        );
      }
    }
  }

  void _filterTagsByNamespace(TagNamespace? namespace) {
    setState(() {
      if (namespace == null) {
        _filteredTags = _allTags;
      } else {
        _filteredTags = _allTags
            .where((tag) => tag.namespaceName == namespace.name)
            .toList();
      }
    });
  }

  Future<MangaListResponse> _fetchMangaByTag() async {
    try {
      final response = await MangaApiService.getMangaByTag(
        _selectedTag!.id,
        page: _currentPage,
        limit: _pageSize,
      );
      return response;
    } catch (e) {
      throw Exception('根据标签获取漫画失败: $e');
    }
  }

  void _goToPage(int page) {
    if (_selectedTag != null && page >= 1 && page <= (_currentMangaResponse?.totalPages ?? 1) && page != _currentPage) {
      setState(() {
        _currentPage = page;
        _mangaListFuture = _fetchMangaByTag();
      });
    }
  }

  void _selectNamespace(TagNamespace namespace) {
    setState(() {
      _selectedNamespace = namespace;
      _selectedTag = null;
      _currentMangaResponse = null;
    });
    _filterTagsByNamespace(namespace);
    _searchController.clear();
  }

  void _selectTag(TagModel tag) {
    setState(() {
      _selectedTag = tag;
      _currentPage = 1;
      _mangaListFuture = _fetchMangaByTag();
    });
  }

  Color _getTagColor(String namespace) {
    switch (namespace) {
      case 'type':
        return const Color(0xFFFFCDD2);
      case 'artist':
        return const Color(0xFFC8E6C9);
      case 'character':
        return const Color(0xFFBBDEFB);
      case 'main':
        return const Color(0xFFFFE0B2);
      case 'sub':
        return const Color(0xFFF3E5F5);
      default:
        return const Color(0xFFE0E0E0);
    }
  }

  Color _getTagTextColor(String namespace) {
    switch (namespace) {
      case 'type':
        return const Color(0xFFC62828);
      case 'artist':
        return const Color(0xFF2E7D32);
      case 'character':
        return const Color(0xFF1565C0);
      case 'main':
        return const Color(0xFFEF6C00);
      case 'sub':
        return const Color(0xFF7B1FA2);
      default:
        return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // 标题
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                '标签分类',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),

          // 搜索框
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索标签...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFFF6B6B)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ),

          // 命名空间标签
          if (_namespaces.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _namespaces.length,
                  itemBuilder: (context, index) {
                    final namespace = _namespaces[index];
                    final isSelected = _selectedNamespace?.id == namespace.id;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(namespace.displayName),
                        selected: isSelected,
                        onSelected: (_) => _selectNamespace(namespace),
                        backgroundColor: Colors.grey[200],
                        selectedColor: const Color(0xFFFF6B6B),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // 标签列表
          if (_filteredTags.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: _filteredTags.map((tag) {
                    final isSelected = _selectedTag?.id == tag.id;
                    return GestureDetector(
                      onTap: () => _selectTag(tag),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF6B6B)
                              : _getTagColor(tag.namespaceName),
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? null
                              : Border.all(color: _getTagColor(tag.namespaceName)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tag.name,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : _getTagTextColor(tag.namespaceName),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tag.count.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            )
          else if (_filteredTags.isEmpty && _selectedNamespace != null)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: Text('没有找到相关标签'),
                ),
              ),
            ),

          // 漫画列表
          if (_selectedTag != null) ...[
            // 选中标签标题
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Text(
                      '${_selectedTag!.name} 相关漫画',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF333333),
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // 漫画网格
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: FutureBuilder<MangaListResponse>(
                future: _mangaListFuture,
                builder: (context, snapshot) {
                  // 正在加载
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverToBoxAdapter(
                      child: Container(
                        height: 200,
                        child: Center(
                          child: LoadingAnimations.mangaLoader(
                            size: 60.0,
                            duration: const Duration(milliseconds: 1200),
                          ),
                        ),
                      ),
                    );
                  }
                  // 加载出错
                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Container(
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                '加载失败: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _mangaListFuture = _fetchMangaByTag();
                                  });
                                },
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  // 加载成功但无数据
                  if (!snapshot.hasData || snapshot.data!.data.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Container(
                        height: 200,
                        child: const Center(
                          child: Text('没有找到相关漫画。'),
                        ),
                      ),
                    );
                  }

                  // 加载成功
                  _currentMangaResponse = snapshot.data!;
                  final mangaList = _currentMangaResponse!.data;

                  if (mangaList.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Container(
                        height: 200,
                        child: const Center(
                          child: Text('没有找到匹配的漫画。'),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildListDelegate([
                      // 漫画网格
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildMangaGridWidget(mangaList),
                      ),

                      // 分页控制
                      if (_currentMangaResponse!.totalPages > 1)
                        PaginationWidget(
                          currentPage: _currentMangaResponse!.page,
                          totalPages: _currentMangaResponse!.totalPages,
                          totalItems: _currentMangaResponse!.total,
                          onPageChanged: _goToPage,
                          itemName: '本漫画',
                        ),
                    ]),
                  );
                },
              ),
            ),
          ],

          // 底部间距
          SliverToBoxAdapter(
            child: SizedBox(height: (_currentMangaResponse?.totalPages ?? 1) > 1 ? 160 : 100),
          ),
        ],
      ),
    );
  }

  // 构建漫画网格视图
  Widget _buildMangaGridWidget(List<Manga> mangaList) {
    // 定义网格的间距
    const double gridSpacing = 16.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200, // 每个子项的最大宽度
        childAspectRatio: 2 / 3.2, // 子项的宽高比，为文字留出更多空间
        crossAxisSpacing: gridSpacing, // 水平间距
        mainAxisSpacing: gridSpacing, // 垂直间距
      ),
      itemCount: mangaList.length,
      itemBuilder: (context, index) {
        return MangaCardWidget(manga: mangaList[index]);
      },
    );
  }

}

