import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../services/reading_progress_service.dart';
import '../services/api_service.dart';
import '../services/drift_reading_progress_manager.dart';
import '../utils/image_cache_manager.dart';
import 'enhanced_reader_page.dart';
import 'manga_detail_page.dart';
import 'loading_animations_simplified.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ReadingProgressService _progressService = ReadingProgressService();

  List<ReadingProgress> _historyList = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasReachedEnd = false;
  final Map<String, Manga> _mangaCache = {};
  static const int _pageSize = 20;
  int _loadedCount = 0;

  late AnimationController _skeletonAnimationController;

  // 记录上次刷新时间，避免过于频繁的刷新
  DateTime? _lastRefreshTime;

  // 记录页面是否可见
  bool _isPageVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _skeletonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadHistory();
    _lastRefreshTime = DateTime.now();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _skeletonAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用从后台回到前台时，检查是否需要刷新
    if (state == AppLifecycleState.resumed) {
      refreshIfNeeded();
    }
  }

  /// 公开的刷新方法，供外部调用
  Future<void> refreshIfNeeded() async {
    final now = DateTime.now();

    // 如果距离上次刷新超过30秒，或者还没有刷新过，则刷新
    if (_lastRefreshTime == null ||
        now.difference(_lastRefreshTime!).inSeconds > 30) {
      await _loadHistory();
      _lastRefreshTime = now;
    }
  }

  Future<void> _loadHistory({bool loadMore = false}) async {
    if (loadMore) {
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // 计算偏移量：加载更多时使用当前已加载数量作为偏移量
      final offset = loadMore ? _loadedCount : 0;
      final limit = _pageSize;
      print('Loading history: loadMore=$loadMore, offset=$offset, limit=$limit');
      final recentRead = await _progressService.getRecentRead(limit: limit, offset: offset);
      print('Loaded ${recentRead.length} history records');

      if (loadMore) {
        setState(() {
          // 直接追加数据（数据库查询已经去重）
          _historyList.addAll(recentRead);
          _loadedCount = _historyList.length;
          _isLoadingMore = false;

          // 如果加载的数据少于_pageSize，说明已经到达末尾
          _hasReachedEnd = recentRead.length < _pageSize;
          print('Loaded more: ${recentRead.length} new items, total: $_loadedCount, reached end: $_hasReachedEnd');
        });
      } else {
        // 立即显示历史记录列表，不等待漫画详情
        setState(() {
          _historyList = recentRead;
          _loadedCount = recentRead.length;
          _isLoading = false;
          _hasReachedEnd = recentRead.length < _pageSize;
          print('Initial load: ${recentRead.length} items, reached end: $_hasReachedEnd');
        });
      }

      // 异步加载漫画详情（不等待完成，立即显示历史记录）
      _loadMangaDetailsInParallel(recentRead);

      // 预加载图片（不等待完成，提升用户体验）
      _preloadImages(recentRead);
    } catch (e) {
      print('Failed to load history: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _loadMangaDetailsInParallel(List<ReadingProgress> recentRead) {
    // 收集需要加载的漫画ID（去重）
    final mangaIdsToLoad = <String>{};
    for (var progress in recentRead) {
      if (!_mangaCache.containsKey(progress.mangaId)) {
        mangaIdsToLoad.add(progress.mangaId);
      }
    }

    if (mangaIdsToLoad.isEmpty) return;

    // 并行加载漫画详情（不等待完成）
    for (var mangaId in mangaIdsToLoad) {
      _loadSingleMangaDetail(mangaId);
    }
  }

  Future<void> _loadSingleMangaDetail(String mangaId) async {
    try {
      // 从本地数据库获取漫画信息
      final mangaProgress = await _getMangaFromLocalDatabase(mangaId);
      if (mangaProgress != null && mounted) {
        setState(() {
          _mangaCache[mangaId] = mangaProgress;
        });
      }
    } catch (e) {
      print('Failed to load manga details for $mangaId: $e');
    }
  }

  /// 从本地数据库获取漫画信息
  Future<Manga?> _getMangaFromLocalDatabase(String mangaId) async {
    try {
      final progressService = ReadingProgressService();
      if (progressService.manager is DriftReadingProgressManager) {
        final driftManager = progressService.manager as DriftReadingProgressManager;

        // 获取漫画进度信息
        final mangaProgress = await driftManager.getMangaProgress(mangaId);
        if (mangaProgress != null) {
          // 创建本地漫画对象，只包含历史页面需要的字段
          return Manga(
            id: mangaId,
            title: mangaProgress.title,
            author: mangaProgress.author,
            description: '',
            coverPath: mangaProgress.coverPath ?? '',
            filePath: '',
            fileName: '',
            fileSize: 0,
            uploadTime: '',
            chapters: [], // 历史页面不需要章节列表
            tags: [],
          );
        }
      }
    } catch (e) {
      print('Failed to get manga from local database: $e');
    }
    return null;
  }

  /// 预加载图片，提升图片显示速度
  void _preloadImages(List<ReadingProgress> recentRead) {
    // 收集需要预加载的图片URL
    final imageUrls = <String>{};
    for (var progress in recentRead) {
      final mangaId = progress.mangaId;
      // 使用API服务生成完整的封面URL
      final imageUrl = MangaApiService.getCoverUrl(mangaId);
      imageUrls.add(imageUrl);
    }

    // 使用与首页相同的预加载策略
    // 并行预加载图片（不等待完成），让 CachedNetworkImage 自动处理缓存
    for (var imageUrl in imageUrls) {
      // 使用智能预加载，避免重复加载
      ImagePreloadManager.smartPreloadImage(context, imageUrl).catchError((_) {
        // 预加载失败不影响主流程
      });
    }
  }

  Future<void> _continueReading(ReadingProgress progress) async {
    try {
      // 通过API获取完整的漫画详情（包含章节信息）
      final manga = await MangaApiService.getMangaById(progress.mangaId);

      // 找到对应的章节
      final chapter = manga.chapters.firstWhere(
        (chapter) => chapter.id == progress.chapterId,
        orElse: () => manga.chapters.first,
      );

      // 跳转到阅读页面
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EnhancedReaderPage(
            manga: manga,
            chapter: chapter,
            chapters: manga.chapters,
          ),
        ),
      );
    } catch (e) {
      // 如果获取失败，显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载漫画详情失败: $e')),
      );
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有阅读历史记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _progressService.clearAllHistory();
        setState(() {
          _historyList.clear();
          _mangaCache.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('历史记录已清除')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除失败: $e')),
        );
      }
    }
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      itemCount: 8, // 显示8个骨架屏项目
      itemBuilder: (context, index) {
        return _buildSkeletonItem();
      },
    );
  }

  Widget _buildSkeletonItem() {
    return AnimatedBuilder(
      animation: _skeletonAnimationController,
      builder: (context, child) {
        final animationValue = _skeletonAnimationController.value;
        final shimmerColor = Colors.grey[300]!.withOpacity(0.7);
        final highlightColor = Colors.grey[100]!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面骨架
                Container(
                  width: 60,
                  height: 80,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment(-1.0, -1.0),
                      end: Alignment(1.0, 1.0),
                      colors: [
                        shimmerColor,
                        highlightColor.withOpacity(animationValue),
                        shimmerColor,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // 内容骨架
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题骨架
                      Container(
                        width: double.infinity,
                        height: 20,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment(-1.0, -1.0),
                            end: Alignment(1.0, 1.0),
                            colors: [
                              shimmerColor,
                              highlightColor.withOpacity(animationValue),
                              shimmerColor,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 章节信息骨架
                      Container(
                        width: 150,
                        height: 16,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment(-1.0, -1.0),
                            end: Alignment(1.0, 1.0),
                            colors: [
                              shimmerColor,
                              highlightColor.withOpacity(animationValue),
                              shimmerColor,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 进度骨架
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 20,
                            decoration: BoxDecoration(
                              color: shimmerColor,
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                begin: Alignment(-1.0, -1.0),
                                end: Alignment(1.0, 1.0),
                                colors: [
                                  shimmerColor,
                                  highlightColor.withOpacity(animationValue),
                                  shimmerColor,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Container(
                            width: 60,
                            height: 16,
                            decoration: BoxDecoration(
                              color: shimmerColor,
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                begin: Alignment(-1.0, -1.0),
                                end: Alignment(1.0, 1.0),
                                colors: [
                                  shimmerColor,
                                  highlightColor.withOpacity(animationValue),
                                  shimmerColor,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // 时间骨架
                      Container(
                        width: 80,
                        height: 14,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment(-1.0, -1.0),
                            end: Alignment(1.0, 1.0),
                            colors: [
                              shimmerColor,
                              highlightColor.withOpacity(animationValue),
                              shimmerColor,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // 按钮骨架
                Container(
                  width: 60,
                  height: 36,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment(-1.0, -1.0),
                      end: Alignment(1.0, 1.0),
                      colors: [
                        shimmerColor,
                        highlightColor.withOpacity(animationValue),
                        shimmerColor,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读历史'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear_all') {
                _clearAllHistory();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: 8),
                    Text('清除所有历史'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadHistory();
        },
        child: Scrollbar(
          thumbVisibility: true, // 始终显示滚动条
          thickness: 6.0, // 滚动条厚度
          radius: const Radius.circular(3.0), // 圆角
          child: _isLoading
              ? _buildSkeletonLoading()
              : _historyList.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            '暂无阅读历史',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (scrollInfo) {
                        // 当滚动到距离底部100像素以内时触发加载更多
                        final threshold = scrollInfo.metrics.maxScrollExtent - 100;
                        final shouldLoadMore = scrollInfo.metrics.pixels >= threshold &&
                            !_isLoadingMore &&
                            !_hasReachedEnd &&
                            scrollInfo.metrics.maxScrollExtent > 0;

                        if (shouldLoadMore) {
                          print('Scrolling near bottom: pixels=${scrollInfo.metrics.pixels}, maxScrollExtent=${scrollInfo.metrics.maxScrollExtent}, threshold=$threshold, reachedEnd=$_hasReachedEnd');
                          _loadHistory(loadMore: true);
                          return true;
                        }
                        return false;
                      },
                      child: ListView.builder(
                        itemCount: _historyList.length + (_isLoadingMore ? 1 : 0) + (_hasReachedEnd && _historyList.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          // 加载指示器
                          if (_isLoadingMore && index == _historyList.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          // 已加载全部提示
                          if (_hasReachedEnd && index == _historyList.length + (_isLoadingMore ? 1 : 0)) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  '已加载全部历史记录',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }

                          // 历史记录项目
                          if (index < _historyList.length) {
                            final progress = _historyList[index];
                            final manga = _mangaCache[progress.mangaId];

                            return HistoryItem(
                              progress: progress,
                              manga: manga,
                              onContinue: () => _continueReading(progress),
                              onDelete: () {
                                // TODO: 实现删除功能
                              },
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}

class HistoryItem extends StatefulWidget {
  final ReadingProgress progress;
  final Manga? manga;
  final VoidCallback onContinue;
  final VoidCallback onDelete;

  const HistoryItem({
    super.key,
    required this.progress,
    this.manga,
    required this.onContinue,
    required this.onDelete,
  });

  @override
  State<HistoryItem> createState() => _HistoryItemState();
}

class _HistoryItemState extends State<HistoryItem> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // 延迟启动动画，创建交错效果
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatProgress(ReadingProgress progress) {
    final percentage = (progress.readingPercentage * 100).toInt();
    return '$percentage%';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 封面图片
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.manga != null
                          ? OptimizedCachedNetworkImage(
                              imageUrl: MangaApiService.getCoverUrl(widget.manga!.id),
                              width: 60,
                              height: 80,
                              fit: BoxFit.cover,
                              // 使用与首页相同的配置：启用进度指示器
                              enableProgressIndicator: true,
                              placeholder: (context, url) => Container(
                                width: 60,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xffe0e0e0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: LoadingAnimations.basicLoader(
                                    color: Colors.grey[400],
                                    size: 16.0,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 60,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xffe0e0e0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            )
                          : Container(
                              width: 60,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                    ),

                    const SizedBox(width: 16),

                    // 漫画信息和进度
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 漫画名称
                          widget.manga != null
                              ? Text(
                                  widget.manga!.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Container(
                                  width: 120,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),

                          const SizedBox(height: 4),

                          // 章节信息
                          widget.manga != null
                              ? Text(
                                  '第${widget.progress.chapterNumber}章: ${widget.progress.chapterTitle}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Container(
                                  width: 180,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),

                          const SizedBox(height: 8),

                          // 阅读进度
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _formatProgress(widget.progress),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // 页码信息
                              Text(
                                '${widget.progress.currentPage + 1}/${widget.progress.totalPages}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // 最后阅读时间
                          Text(
                            _formatTime(widget.progress.lastReadTime),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // 继续阅读按钮
                    ElevatedButton(
                      onPressed: widget.onContinue,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        '继续',
                        style: TextStyle(fontSize: 14),
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
}