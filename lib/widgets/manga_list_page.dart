import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import 'manga_detail_page.dart';
import 'carousel_widget.dart';
import 'page_transitions.dart';
import 'loading_animations_simplified.dart';
import '../utils/image_cache_manager.dart';

// 整个漫画列表页面的主 Widget
class MangaListPage extends StatefulWidget {
  const MangaListPage({super.key});

  @override
  State<MangaListPage> createState() => _MangaListPageState();
}

class _MangaListPageState extends State<MangaListPage> {
  late Future<MangaListResponse> _mangaListFuture;
  int _currentPage = 1;
  final int _pageSize = 20;
  MangaListResponse? _currentResponse;
  final CarouselWidgetKey _carouselKey = const CarouselWidgetKey();

  @override
  void initState() {
    super.initState();
    // 初始化时获取漫画列表数据
    _mangaListFuture = _fetchMangaList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: CustomScrollView(
          slivers: [

          // 轮播图
          SliverToBoxAdapter(
            child: CarouselWidget(key: _carouselKey),
          ),


          // 漫画列表标题
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    '全部漫画',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(2),
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
                                  _mangaListFuture = _fetchMangaList();
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
                        child: Text('没有找到任何漫画。'),
                      ),
                    ),
                  );
                }

                // 加载成功
                _currentResponse = snapshot.data!;
                final mangaList = _currentResponse!.data;

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
                    _buildMangaGridWidget(mangaList),

                    // 分页控制
                    if (_currentResponse!.totalPages > 1)
                      _buildPaginationControls(),
                  ]),
                );
              },
            ),
          ),

          // 底部间距
          SliverToBoxAdapter(
            child: SizedBox(height: (_currentResponse?.totalPages ?? 1) > 1 ? 160 : 100), // 为分页控件留出空间
          ),
        ],
      ),
    ),
    );
  }

  // 下拉刷新回调函数
  Future<void> _onRefresh() async {
    try {
      // 重置到第一页
      setState(() {
        _currentPage = 1;
        _mangaListFuture = _fetchMangaList();
      });

      // 同时重新加载轮播图数据
      if (_carouselKey.currentState != null) {
        await _carouselKey.currentState!.reloadCarouselData();
      }

      // 等待漫画列表数据加载完成
      await _mangaListFuture;
    } catch (e) {
      // 错误处理 - RefreshIndicator 会自动处理错误状态
    }
  }

  // 获取漫画列表数据
  Future<MangaListResponse> _fetchMangaList() async {
    try {
      final response = await MangaApiService.getMangaList(page: _currentPage, limit: _pageSize);
      return response;
    } catch (e) {
      throw Exception('获取漫画列表失败: $e');
    }
  }

  
  // 切换到指定页面
  void _goToPage(int page) {
    if (page >= 1 && page <= (_currentResponse?.totalPages ?? 1) && page != _currentPage) {
      setState(() {
        _currentPage = page;
        _mangaListFuture = _fetchMangaList();
      });
    }
  }

  // 构建分页控制组件
  Widget _buildPaginationControls() {
    if (_currentResponse == null) return const SizedBox.shrink();

    final totalPages = _currentResponse!.totalPages;
    final currentPage = _currentResponse!.page;

    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 页码信息
          Text(
            '第 $currentPage / $totalPages 页 (共 ${_currentResponse!.total} 本漫画)',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 12),

          // 分页按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 上一页按钮
              IconButton(
                onPressed: currentPage > 1 ? () => _goToPage(currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left),
                color: currentPage > 1 ? Theme.of(context).primaryColor : Colors.grey,
              ),

              // 页码按钮
              _buildPageButtons(currentPage, totalPages),

              // 下一页按钮
              IconButton(
                onPressed: currentPage < totalPages ? () => _goToPage(currentPage + 1) : null,
                icon: const Icon(Icons.chevron_right),
                color: currentPage < totalPages ? Theme.of(context).primaryColor : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建页码按钮
  Widget _buildPageButtons(int currentPage, int totalPages) {
    List<Widget> buttons = [];

    // 计算显示的页码范围
    int startPage = (currentPage - 2).clamp(1, totalPages);
    int endPage = (currentPage + 2).clamp(1, totalPages);

    // 确保至少显示5个页码（如果总页数允许）
    if (endPage - startPage < 4) {
      if (startPage == 1) {
        endPage = (startPage + 4).clamp(1, totalPages);
      } else if (endPage == totalPages) {
        startPage = (endPage - 4).clamp(1, totalPages);
      }
    }

    // 添加第一页
    if (startPage > 1) {
      buttons.add(_buildPageButton(1, currentPage));
      if (startPage > 2) {
        buttons.add(const Text(' ... ', style: TextStyle(color: Colors.grey)));
      }
    }

    // 添加中间页码
    for (int i = startPage; i <= endPage; i++) {
      buttons.add(_buildPageButton(i, currentPage));
    }

    // 添加最后一页
    if (endPage < totalPages) {
      if (endPage < totalPages - 1) {
        buttons.add(const Text(' ... ', style: TextStyle(color: Colors.grey)));
      }
      buttons.add(_buildPageButton(totalPages, currentPage));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: buttons,
    );
  }

  // 构建单个页码按钮
  Widget _buildPageButton(int pageNumber, int currentPage) {
    final isActive = pageNumber == currentPage;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 根据主题亮度决定文本颜色
    final activeTextColor = colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final inactiveTextColor = theme.textTheme.bodyLarge?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => _goToPage(pageNumber),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? colorScheme.primary : theme.dividerColor,
            ),
          ),
          child: Text(
            '$pageNumber',
            style: TextStyle(
              color: isActive ? activeTextColor : inactiveTextColor,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
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

// 单个漫画卡片的 Widget
class MangaCardWidget extends StatefulWidget {
  final Manga manga;

  const MangaCardWidget({super.key, required this.manga});

  @override
  State<MangaCardWidget> createState() => _MangaCardWidgetState();
}

class _MangaCardWidgetState extends State<MangaCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _shadowAnimation = Tween<double>(
      begin: 2.0,
      end: 12.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverChange(bool isHovered) {
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHoverChange(true),
      onExit: (_) => _onHoverChange(false),
      cursor: SystemMouseCursors.click,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Card(
            elevation: _shadowAnimation.value,
            shadowColor: Colors.black.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  PageTransitions.customPageRoute(
                    child: MangaDetailPage(manga: widget.manga),
                    transitionBuilder: PageTransitions.slideTransition,
                  ),
                );
              },
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCoverImage(),
                    _buildMangaInfo(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 构建封面图片部分
  Widget _buildCoverImage() {
    return Expanded(
      // Expanded 占据所有剩余空间
      child: OptimizedCachedNetworkImage(
        imageUrl: MangaApiService.getCoverUrl(widget.manga.id),
        fit: BoxFit.cover, // 填充并裁剪以适应空间，不变形
        placeholder: (context, url) => Container(
          color: const Color(0xffe0e0e0),
          child: Center(
            child: LoadingAnimations.basicLoader(
              color: Colors.grey[400],
              size: 16.0,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: const Color(0xffe0e0e0),
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }

  // 构建漫画信息部分
  Widget _buildMangaInfo() {
    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // mainAxisSize 设置为 min，使其高度由内容决定
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Text(
            widget.manga.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // 作者
          Text(
            widget.manga.author,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
