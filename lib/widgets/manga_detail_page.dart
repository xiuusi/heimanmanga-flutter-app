import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import '../services/reading_progress_service.dart';
import 'enhanced_reader_page.dart';
import 'page_transitions.dart';
import 'loading_animations_simplified.dart';
import '../utils/image_cache_manager.dart';


class MangaDetailPage extends StatefulWidget {
  final Manga manga;

  const MangaDetailPage({Key? key, required this.manga}) : super(key: key);

  @override
  State<MangaDetailPage> createState() => _MangaDetailPageState();
}

class _MangaDetailPageState extends State<MangaDetailPage> {
  late Future<Manga> _mangaDetailFuture;
  final ReadingProgressService _progressService = ReadingProgressService();

  // 用于存储章节阅读状态的Map
  Map<String, bool> _chapterReadStatus = {};

  // 阅读按钮相关状态
  String _readButtonText = "开始阅读";
  String _targetChapterId = "";
  int _targetPageNum = 1;

  @override
  void initState() {
    super.initState();
    _mangaDetailFuture = _loadMangaDetail();
  }

  /// 加载所有章节的阅读状态
  Future<void> _loadChapterReadStatus(Manga manga) async {
    final Map<String, bool> statusMap = {};

    for (final chapter in manga.chapters) {
      final progress = await _progressService.getProgress(widget.manga.id, chapterId: chapter.id);
      final isChapterRead = progress?.isChapterRead() ?? false;
      statusMap[chapter.id] = isChapterRead;
    }

    // 只有当状态确实发生变化时才更新UI
    if (mounted && !_areMapsEqual(_chapterReadStatus, statusMap)) {
      setState(() {
        _chapterReadStatus = statusMap;
      });
    }
  }

  /// 比较两个Map是否相等
  bool _areMapsEqual(Map<String, bool> map1, Map<String, bool> map2) {
    if (map1.length != map2.length) return false;

    for (final key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }

    return true;
  }

  /// 计算阅读按钮状态（类似web端逻辑）
  Future<void> _calculateReadButtonState(Manga manga) async {
    try {
      // 获取阅读进度
      final progress = await _progressService.getProgress(widget.manga.id);

      // 默认从第一章第一页开始
      String targetChapterId = manga.chapters.isNotEmpty ? manga.chapters[0].id : "";
      int targetPageNum = 1;
      String buttonText = "开始阅读";

      if (progress != null) {
        // 查找进度记录中的章节是否在当前漫画章节列表中
        final progressChapters = manga.chapters.where((chapter) => chapter.id == progress.chapterId).toList();

        if (progressChapters.isNotEmpty) {
          // 如果有匹配的章节，使用第一个匹配的章节
          final progressChapter = progressChapters.first;
          buttonText = "继续阅读";
          targetChapterId = progress.chapterId;
          targetPageNum = progress.currentPage + 1; // currentPage是0-based，转换为1-based
        }
      }

      // 确保在没有阅读记录时也能正常开始阅读
      if (targetChapterId.isEmpty && manga.chapters.isNotEmpty) {
        targetChapterId = manga.chapters[0].id;
      }

      if (mounted) {
        setState(() {
          _readButtonText = buttonText;
          _targetChapterId = targetChapterId;
          _targetPageNum = targetPageNum;
        });
      }
    } catch (e, stackTrace) {
      print('计算阅读按钮状态失败: $e');
      print('堆栈跟踪: $stackTrace');
    }
  }

  /// 处理阅读按钮点击（类似web端readManga函数）
  void _handleReadButtonTap() {
    if (_targetChapterId.isEmpty) return;

    final targetChapters = widget.manga.chapters.where((chapter) => chapter.id == _targetChapterId).toList();
    final targetChapter = targetChapters.isNotEmpty ? targetChapters.first : widget.manga.chapters[0];

    // 记录用户选择了这个章节，从指定页码开始阅读
    _progressService.saveProgress(
      manga: widget.manga,
      chapter: targetChapter,
      currentPage: _targetPageNum - 1, // 转换为0-based
      totalPages: targetChapter.totalPages, // 使用实际的章节页数
    );

    // 导航到阅读页面
    Navigator.push(
      context,
      PageTransitions.customPageRoute(
        child: EnhancedReaderPage(
          manga: widget.manga,
          chapter: targetChapter,
          chapters: widget.manga.chapters,
        ),
        transitionBuilder: PageTransitions.fadeTransition,
      ),
    );
  }

  Future<Manga> _loadMangaDetail() async {
    try {
      return await MangaApiService.getMangaById(widget.manga.id);
    } catch (e) {
      throw Exception('获取漫画详情失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manga.title),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder<Manga>(
        future: _mangaDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: LoadingAnimations.pulseLoader(
                size: 80.0,
                duration: const Duration(milliseconds: 1000),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '加载失败: ${snapshot.error}',
                    style: TextStyle(color: Colors.red[400]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _mangaDetailFuture = _loadMangaDetail();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          final manga = snapshot.data!;

          // 在漫画数据加载完成后，异步加载章节阅读状态和计算按钮状态（仅第一次）
          if (_chapterReadStatus.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadChapterReadStatus(manga);
              _calculateReadButtonState(manga);
            });
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMangaHeader(manga),
                _buildMangaDescription(manga),
                _buildChapterList(manga),
              ],
            ),
          );
        },
      ),
    );
  }

  // 构建漫画头部信息（封面和基本信息）
  Widget _buildMangaHeader(Manga manga) {
    return Container(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图片 - 使用1:1.5比例且不裁切
            Container(
              width: 153, // 230 / 1.5 ≈ 153
              height: 230, // 高度提高到230
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: OptimizedCachedNetworkImage(
                imageUrl: MangaApiService.getCoverUrl(manga.id),
                width: 153,
                height: 230,
                fit: BoxFit.contain, // 改为contain以显示完整图片
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: Center(
                    child: LoadingAnimations.dotLoader(
                      dotSize: 6.0,
                      duration: const Duration(milliseconds: 800),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: Icon(Icons.broken_image, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 基本信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manga.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '作者: ${manga.author}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 标签
                  if (manga.tags.isNotEmpty)
                    _buildTagsSection(manga.tags),
                  const SizedBox(height: 16),
                  // 开始阅读/继续阅读按钮
                  ElevatedButton(
                    onPressed: _targetChapterId.isNotEmpty ? _handleReadButtonTap : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      _readButtonText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建标签显示区域
  Widget _buildTagsSection(List<TagModel> tags) {
    // 按命名空间分组标签
    final Map<String, List<TagModel>> groupedTags = {};

    for (final tag in tags) {
      final namespace = _getNamespaceName(tag.namespaceId);
      // 过滤掉角色命名空间
      if (namespace != 'character') {
        if (!groupedTags.containsKey(namespace)) {
          groupedTags[namespace] = [];
        }
        groupedTags[namespace]!.add(tag);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          '标签',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...groupedTags.entries.map((entry) {
          final namespace = entry.key;
          final namespaceTags = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8, // 统一标签之间的间距
                children: namespaceTags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getTagColor(namespace).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getTagColor(namespace).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      tag.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getTagColor(namespace),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12), // 统一不同命名空间标签组之间的间距
            ],
          );
        }).toList(),
      ],
    );
  }

  // 根据命名空间ID获取命名空间名称
  String _getNamespaceName(int namespaceId) {
    switch (namespaceId) {
      case 1: return 'type';
      case 2: return 'artist';
      case 3: return 'character';
      case 4: return 'main';
      case 5: return 'sub';
      default: return 'unknown';
    }
  }

  // 根据命名空间获取标签颜色
  Color _getTagColor(String namespace) {
    switch (namespace) {
      case 'type':
        return const Color(0xFF1565C0); // 蓝色
      case 'artist':
        return const Color(0xFF7B1FA2); // 紫色
      case 'main':
        return const Color(0xFFEF6C00); // 橙色
      case 'sub':
        return const Color(0xFF757575); // 灰色
      default:
        return const Color(0xFFFF6B6B); // 默认红色
    }
  }

  // 构建漫画描述
  Widget _buildMangaDescription(Manga manga) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '简介',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              manga.description.isNotEmpty
                  ? manga.description
                  : '暂无简介',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建章节列表
  Widget _buildChapterList(Manga manga) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '章节列表 (${manga.chapters.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (manga.chapters.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    '暂无章节',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: manga.chapters.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor,
                ),
                itemBuilder: (context, index) {
                  final chapter = manga.chapters[index];
                  final isChapterRead = _chapterReadStatus[chapter.id] ?? false;

                  return GestureDetector(
                    onLongPress: () {
                      if (isChapterRead) {
                        _showCancelReadDialog(context, manga, chapter);
                      }
                    },
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isChapterRead
                            ? Colors.green
                            : const Color(0xFFFF6B6B),
                        foregroundColor: Colors.white,
                        child: Text(
                          '${chapter.number}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              chapter.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isChapterRead)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '已阅读',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '文件大小: ${(chapter.fileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          PageTransitions.customPageRoute(
                            child: EnhancedReaderPage(
                              manga: manga,
                              chapter: chapter,
                              chapters: manga.chapters,  // 传递完整章节列表
                            ),
                            transitionBuilder: PageTransitions.fadeTransition,
                          ),
                        );

                        // 从阅读器返回后刷新阅读状态
                        if (mounted) {
                          _loadChapterReadStatus(manga);
                        }
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 显示取消阅读记录的对话框
  void _showCancelReadDialog(BuildContext context, Manga manga, Chapter chapter) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消阅读记录'),
        content: Text('确定要取消"${chapter.title}"的阅读记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _progressService.markChapterAsRead(
                mangaId: manga.id,
                chapterId: chapter.id,
                isRead: false,
              );
              Navigator.of(context).pop();

              // 立即更新本地状态，确保UI实时响应
              setState(() {
                _chapterReadStatus[chapter.id] = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定取消'),
          ),
        ],
      ),
    );
  }
}
