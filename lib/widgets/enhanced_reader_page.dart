import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import '../services/reading_progress_service.dart';
import '../utils/reader_gestures.dart';
import '../utils/image_cache_manager.dart';
import '../utils/page_animation_manager.dart';
import '../utils/error_boundary.dart';
import '../utils/debug_logger.dart';
import '../utils/crash_diagnostic.dart';
import '../utils/performance_monitor.dart';
import 'dart:async';
import 'dart:math' as math;

/// UI状态管理类
class ReaderUIState {
  // 阅读状态
  int currentPage = 0;
  bool showControls = true;
  bool isLoading = true;
  String? errorMessage;
  List<String> imageUrls = [];

  // 章节跳转状态
  int currentChapterIndex = 0;
  bool isLoadingNextChapter = false;

  // UI状态
  bool isInFullscreen = false;
  bool showSettingsPanel = false;

  // 缩放和拖拽
  double currentScale = 1.0;
  Offset panOffset = Offset.zero;
  Offset cumulativePanOffset = Offset.zero;

  // 配置相关
  ReadingDirection readingDirection = ReadingDirection.rightToLeft;
  bool dualPageMode = false;
  bool shiftDoublePage = false;

  ReaderUIState();

  /// 复制状态
  ReaderUIState copyWith({
    int? currentPage,
    bool? showControls,
    bool? isLoading,
    String? errorMessage,
    List<String>? imageUrls,
    int? currentChapterIndex,
    bool? isLoadingNextChapter,
    bool? isInFullscreen,
    bool? showSettingsPanel,
    double? currentScale,
    Offset? panOffset,
    Offset? cumulativePanOffset,
    ReadingDirection? readingDirection,
    bool? dualPageMode,
    bool? shiftDoublePage,
  }) {
    return ReaderUIState()
      ..currentPage = currentPage ?? this.currentPage
      ..showControls = showControls ?? this.showControls
      ..isLoading = isLoading ?? this.isLoading
      ..errorMessage = errorMessage ?? this.errorMessage
      ..imageUrls = imageUrls ?? this.imageUrls
      ..currentChapterIndex = currentChapterIndex ?? this.currentChapterIndex
      ..isLoadingNextChapter = isLoadingNextChapter ?? this.isLoadingNextChapter
      ..isInFullscreen = isInFullscreen ?? this.isInFullscreen
      ..showSettingsPanel = showSettingsPanel ?? this.showSettingsPanel
      ..currentScale = currentScale ?? this.currentScale
      ..panOffset = panOffset ?? this.panOffset
      ..cumulativePanOffset = cumulativePanOffset ?? this.cumulativePanOffset
      ..readingDirection = readingDirection ?? this.readingDirection
      ..dualPageMode = dualPageMode ?? this.dualPageMode
      ..shiftDoublePage = shiftDoublePage ?? this.shiftDoublePage;
  }
}


/// 增强版阅读器页面（Mihon风格）
class EnhancedReaderPage extends StatefulWidget {
  // MethodChannel 定义
  static const platform = MethodChannel('io.xiuusi.heimanmanga/volume_keys');
  final Manga manga;
  final Chapter chapter;
  final List<Chapter> chapters;  // 完整的章节列表
  final ReadingGestureConfig? initialConfig;

  const EnhancedReaderPage({
    Key? key,
    required this.manga,
    required this.chapter,
    required this.chapters,  // 添加章节列表参数
    this.initialConfig,
  }) : super(key: key);

  @override
  _EnhancedReaderPageState createState() => _EnhancedReaderPageState();
}

class _EnhancedReaderPageState extends State<EnhancedReaderPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // 基础控制器
  late PageController _pageController;
  late ScrollController _scrollController;

  // UI状态管理
  late ReaderUIState _uiState;

  // 配置
  late ReadingGestureConfig _config;

  // 定时器
  Timer? _hideTimer;

  // 动画控制器
  late AnimationController _settingsAnimationController;
  late AnimationController _controlsAnimationController;

  // 预加载
  Set<int> _preloadedPages = <int>{};
  static const int _preloadRange = 5; // 增加预加载范围
  static const int _chapterEndPreloadThreshold = 3; // 章节末尾预加载阈值
  bool _isNearChapterEnd = false;
  Timer? _nextChapterPreloadTimer;
  Timer? _memoryCleanupTimer; // 内存清理定时器

  // 图片尺寸缓存
  Map<int, Size> _imageSizes = <int, Size>{};


  // 阅读进度
  double _readingProgress = 0.0;
  Timer? _progressSaveTimer;

  // 阅读进度管理器
  final ReadingProgressService _progressService = ReadingProgressService();
  ReadingProgress? _existingProgress;
  bool _hasShownJumpPrompt = false;

  // 音量键监听
  late FocusNode _focusNode;
  bool _volumeButtonNavigationEnabled = false;
  bool _isChannelListenerSetup = false;

  // 最后一章退出逻辑
  bool _isLastChapterDialogShown = false;

  // 手势处理器引用
  TouchGestureHandler? _gestureHandler;

  @override
  void initState() {
    DebugLogger.methodEnter('EnhancedReaderPage.initState', params: {
      'mangaId': widget.manga.id,
      'chapterId': widget.chapter.id,
      'chaptersCount': widget.chapters.length,
      'initialConfig': widget.initialConfig?.readingDirection.toString(),
    });

    // 初始化崩溃诊断
    CrashDiagnostic.reset();
    CrashDiagnostic.addDiagnostic('mangaId', widget.manga.id);
    CrashDiagnostic.addDiagnostic('chapterId', widget.chapter.id);
    CrashDiagnostic.addDiagnostic('chaptersCount', widget.chapters.length);
    CrashDiagnostic.addDiagnostic('initialConfig', widget.initialConfig?.readingDirection.toString());

    // 开始性能监控
    PerformanceMonitor.startMonitoring();

    super.initState();

    // 注册WidgetsBinding观察者
    WidgetsBinding.instance.addObserver(this);

    // 初始化配置
    _config = widget.initialConfig ?? ReadingGestureConfig(
      readingDirection: ReadingDirection.rightToLeft,
      tapToZoom: false,
      volumeButtonNavigation: true,
      fullscreenOnTap: true,
      keepScreenOn: true,
      autoHideControlsDelay: Duration(seconds: 3),
      enableImmersiveMode: true,
      dualPageMode: false,
      shiftDoublePage: false,
      gestureActions: const {
        TouchArea.leftEdge: {
          GestureType.tap: 'previous_page',
        },
        TouchArea.leftZone: {
          GestureType.tap: 'previous_page',
        },
        TouchArea.centerZone: {
          GestureType.tap: 'toggle_ui',
          GestureType.pinchZoomIn: 'zoom_in',
          GestureType.pinchZoomOut: 'zoom_out',
        },
        TouchArea.rightZone: {
          GestureType.tap: 'next_page',
        },
        TouchArea.rightEdge: {
          GestureType.tap: 'next_page',
        },
      },
    );

    // 初始化UI状态
    _uiState = ReaderUIState()
      ..readingDirection = _config.readingDirection
      ..dualPageMode = _config.dualPageMode
      ..shiftDoublePage = _config.shiftDoublePage;

    _volumeButtonNavigationEnabled = _config.volumeButtonNavigation;

    // 初始化焦点节点
    _focusNode = FocusNode();

    // 设置 MethodChannel 监听 - 关键！
    _setupVolumeKeyListener();

    // 启用音量键拦截
    _enableVolumeKeyInterception(true);

    // 初始化当前章节索引
    _uiState.currentChapterIndex = widget.chapters.indexWhere((chapter) => chapter.id == widget.chapter.id);
    if (_uiState.currentChapterIndex == -1) {
      _uiState.currentChapterIndex = 0;
    }

    // 初始化控制器
    _pageController = PageController(initialPage: _uiState.currentPage);
    _scrollController = ScrollController();

    // 初始化动画控制器
    _settingsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // 设置系统UI
    _setSystemUI();

    // 加载图片
    _loadChapterImages();

    // 开始自动隐藏计时器
    _startHideTimer();

    // 开始进度保存计时器
    _startProgressSaveTimer();

    // 开始内存清理定时器
    _startMemoryCleanupTimer();

    // 加载阅读进度
    _loadReadingProgress();

    // 请求焦点以接收按键事件
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _setSystemUI() {
    if (_config.keepScreenOn) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    DebugLogger.methodExit('EnhancedReaderPage.initState');
  }

  void _loadChapterImages() async {
    DebugLogger.methodEnter('_loadChapterImages');
    CrashDiagnostic.logMethodCall('_loadChapterImages');
    PerformanceMonitor.startTimer('loadChapterImages');

    try {
      DebugLogger.log('开始加载章节图片');
      CrashDiagnostic.addDiagnostic('loadingState', 'loading_images');

      final apiImageFiles = await MangaApiService.getChapterImageFiles(
        widget.manga.id,
        widget.chapter.id,
      );

      if (!mounted) return;

      if (apiImageFiles.isNotEmpty) {
        DebugLogger.log('获取到 ${apiImageFiles.length} 张图片');
        CrashDiagnostic.addDiagnostic('apiImageFilesCount', apiImageFiles.length);

        List<String> imageUrls = [];
        for (String fileName in apiImageFiles) {
          imageUrls.add(
            MangaApiService.getChapterImageUrl(
              widget.manga.id,
              widget.chapter.id,
              fileName,
            ),
          );
        }

        DebugLogger.log('构建了 ${imageUrls.length} 个图片URL');
        CrashDiagnostic.addDiagnostic('imageUrlsCount', imageUrls.length);
        CrashDiagnostic.addDiagnostic('imageUrlsSample', imageUrls.take(3).toList());

        setState(() {
          _uiState = _uiState.copyWith(
            imageUrls: imageUrls,
            isLoading: false,
          );
        });

        // 记录图片加载性能
        PerformanceMonitor.recordMemoryUsage('ChapterImagesLoaded', imageUrls.length * 1024 * 1024);

        // 预加载附近页面
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preloadNearbyPages();
        });

        // 异步加载图片尺寸信息
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // 预加载所有图片的尺寸（异步进行，不影响初始加载速度）
          for (int i = 0; i < imageUrls.length; i++) {
            await _getImageSize(imageUrls[i], i);
          }
        });
      } else {
        setState(() {
          _uiState = _uiState.copyWith(
            errorMessage: "无法获取章节图片列表",
            isLoading: false,
          );
        });
      }
    } catch (e, stackTrace) {
      DebugLogger.error('加载章节图片失败', error: e, stackTrace: stackTrace);
      CrashDiagnostic.logCrash('加载章节图片失败', error: e, stackTrace: stackTrace);
      PerformanceMonitor.recordError('loadChapterImages');

      setState(() {
        _uiState = _uiState.copyWith(
          errorMessage: "加载章节失败: $e",
          isLoading: false,
        );
      });
    } finally {
      CrashDiagnostic.addDiagnostic('loadingState', 'completed');
      PerformanceMonitor.stopTimer('loadChapterImages');
      DebugLogger.methodExit('_loadChapterImages');
    }
  }

  /// 加载阅读进度
  Future<void> _loadReadingProgress() async {
    try {
      await _progressService.init();
      // 按章节获取阅读进度
      _existingProgress = await _progressService.getProgress(widget.manga.id, chapterId: widget.chapter.id);

      if (_existingProgress != null && mounted) {
        // 检查是否需要显示跳转提示（仅当是当前章节且有进度时）
        if (_existingProgress!.shouldPromptJump(widget.chapter.id)) {
          _showJumpToProgressPrompt();
        }
      }
    } catch (e) {
      // 加载阅读进度失败
    }
  }

  /// 显示跳转到进度的提示
  void _showJumpToProgressPrompt() {
    if (_hasShownJumpPrompt || _existingProgress == null) return;

    final currentPage = _existingProgress!.currentPage + 1;
    final totalPages = _existingProgress!.totalPages;
    final percentage = (_existingProgress!.readingPercentage * 100).toStringAsFixed(1);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('检测到阅读进度'),
        content: Text('上次阅读到第 $currentPage/$totalPages 页 ($percentage%)\n是否跳转到上次阅读位置？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _hasShownJumpPrompt = true;
            },
            child: Text('从头阅读'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _jumpToProgress();
              _hasShownJumpPrompt = true;
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF6B6B),
            ),
            child: Text('跳转'),
          ),
        ],
      ),
    );
  }

  /// 获取当前章节
  Chapter _getCurrentChapter() {
    if (_uiState.currentChapterIndex >= 0 && _uiState.currentChapterIndex < widget.chapters.length) {
      return widget.chapters[_uiState.currentChapterIndex];
    }
    return widget.chapter;
  }

  /// 跳转到进度位置
  void _jumpToProgress() {
    if (_existingProgress == null) return;

    // 如果图片还没有加载完成，等待加载完成后再跳转
    if (_uiState.imageUrls.isEmpty) {
      _showSnackBar('正在加载图片，请稍后...');
      // 设置一个监听器，当图片加载完成后自动跳转
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _waitForImagesAndJump();
      });
      return;
    }

    _performJumpToProgress();
  }

  /// 等待图片加载完成后执行跳转
  void _waitForImagesAndJump() async {
    // 最多等待5秒
    final maxWaitTime = Duration(seconds: 5);
    final startTime = DateTime.now();

    while (_uiState.imageUrls.isEmpty && DateTime.now().difference(startTime) < maxWaitTime) {
      await Future.delayed(Duration(milliseconds: 100));
    }

    if (_uiState.imageUrls.isNotEmpty && mounted) {
      _performJumpToProgress();
    } else if (mounted) {
      _showSnackBar('图片加载超时，请重试');
    }
  }

  /// 执行实际的跳转逻辑
  void _performJumpToProgress() {
    if (_existingProgress == null || _uiState.imageUrls.isEmpty) return;

    final targetPage = _existingProgress!.currentPage.clamp(0, _uiState.imageUrls.length - 1);

    setState(() {
      _uiState = _uiState.copyWith(currentPage: targetPage);
    });

    if (_uiState.readingDirection == ReadingDirection.vertical ||
        _uiState.readingDirection == ReadingDirection.webtoon) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          targetPage * MediaQuery.of(context).size.height,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    } else {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          targetPage,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }

    HapticFeedbackManager.mediumImpact();
    _showSnackBar('已跳转到第 ${targetPage + 1} 页');
  }

  /// 标记当前章节为已阅读
  Future<void> _markCurrentChapterAsRead() async {
    try {
      final currentChapter = _getCurrentChapter();

      await _progressService.markChapterAsRead(
        mangaId: widget.manga.id,
        chapterId: currentChapter.id,
        isRead: true,
      );
    } catch (e) {
      // 自动标记章节失败
    }
  }

  /// 保存阅读进度
  Future<void> _saveReadingProgress() async {
    if (_uiState.imageUrls.isEmpty) {
      return;
    }

    try {
      final currentChapter = _getCurrentChapter();

      await _progressService.saveProgress(
        manga: widget.manga,
        chapter: currentChapter,  // 使用当前章节
        currentPage: _uiState.currentPage,
        totalPages: _uiState.imageUrls.length,
      );
    } catch (e) {
      // 保存阅读进度失败
    }
  }

  void _preloadNearbyPages() {
    if (_uiState.imageUrls.isEmpty) return;

    // 清理过远的预加载页面，释放内存
    _cleanupDistantPreloadedPages();

    // 根据当前页面索引预加载图片
    int start = (_uiState.currentPage - _preloadRange).clamp(0, _uiState.imageUrls.length - 1);
    int end = (_uiState.currentPage + _preloadRange).clamp(0, _uiState.imageUrls.length - 1);

    // 智能预加载：优先预加载靠近当前页面的图片
    List<int> pagesToPreload = [];
    for (int i = start; i <= end; i++) {
      if (!_preloadedPages.contains(i)) {
        pagesToPreload.add(i);
      }
    }

    // 按距离排序，优先预加载靠近当前页面的图片
    pagesToPreload.sort((a, b) =>
      (a - _uiState.currentPage).abs().compareTo((b - _uiState.currentPage).abs())
    );

    // 渐进式预加载
    for (int i = 0; i < pagesToPreload.length; i++) {
      final pageIndex = pagesToPreload[i];
      _preloadedPages.add(pageIndex);

      // 延迟预加载较远的图片
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted) {
          precacheImage(
            CachedNetworkImageProvider(_uiState.imageUrls[pageIndex]),
            context,
            onError: (exception, stackTrace) {
              _preloadedPages.remove(pageIndex);
            },
          );
        }
      });
    }

    // 检查是否需要预加载下一章节
    _checkNextChapterPreload();
  }

  /// 清理距离当前页面过远的预加载页面
  void _cleanupDistantPreloadedPages() {
    final cleanupThreshold = _preloadRange * 2; // 清理距离超过预加载范围2倍的页面

    _preloadedPages.removeWhere((pageIndex) {
      final distance = (pageIndex - _uiState.currentPage).abs();
      return distance > cleanupThreshold;
    });
  }

  /// 清理章节切换时的资源
  void _cleanupChapterResources() {
    // 清空预加载记录
    _preloadedPages.clear();

    // 清空图片尺寸缓存
    _imageSizes.clear();

    // 取消下一章节预加载
    _cancelNextChapterPreload();

    // 重置章节末尾检测状态
    _isNearChapterEnd = false;
  }

  /// 检查是否需要预加载下一章节
  void _checkNextChapterPreload() {
    if (_uiState.imageUrls.isEmpty) return;

    // 根据当前页面索引判断是否接近章节末尾
    // 在智能双页模式下，我们需要考虑页面总数
    final currentPageIndex = _uiState.dualPageMode ? _getPageIndexOfImage(_uiState.currentPage) : _uiState.currentPage;
    final totalPageCount = _uiState.dualPageMode ? _getPageCount() : _uiState.imageUrls.length;

    final isNearEnd = currentPageIndex >= totalPageCount - _chapterEndPreloadThreshold;

    // 如果接近章节末尾且还没有预加载下一章节
    if (isNearEnd && !_isNearChapterEnd) {
      _isNearChapterEnd = true;
      _preloadNextChapter();
    } else if (!isNearEnd && _isNearChapterEnd) {
      _isNearChapterEnd = false;
      _cancelNextChapterPreload();
    }
  }

  /// 预加载下一章节
  Future<void> _preloadNextChapter() async {
    final nextChapterIndex = _uiState.currentChapterIndex + 1;

    // 检查是否有下一章
    if (nextChapterIndex >= widget.chapters.length) {
      return;
    }

    // 取消之前的预加载定时器
    _nextChapterPreloadTimer?.cancel();

    // 延迟预加载，避免影响当前章节的加载性能
    _nextChapterPreloadTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final nextChapter = widget.chapters[nextChapterIndex];

        // 获取下一章节的图片列表
        final apiImageFiles = await MangaApiService.getChapterImageFiles(
          widget.manga.id,
          nextChapter.id,
        );

        if (apiImageFiles.isNotEmpty) {
          // 预加载下一章节的前几页，限制并发数量避免内存压力
          final preloadCount = math.min(3, apiImageFiles.length); // 减少预加载数量

          for (int i = 0; i < preloadCount; i++) {
            final imageUrl = MangaApiService.getChapterImageUrl(
              widget.manga.id,
              nextChapter.id,
              apiImageFiles[i],
            );

            // 使用延迟预加载避免阻塞，增加延迟时间
            Future.delayed(Duration(milliseconds: i * 200), () {
              if (mounted) {
                precacheImage(
                  CachedNetworkImageProvider(imageUrl),
                  context,
                );
              }
            });
          }
        }
      } catch (e) {
        // 预加载下一章节失败，不影响当前阅读
      }
    });
  }

  /// 取消下一章节预加载
  void _cancelNextChapterPreload() {
    _nextChapterPreloadTimer?.cancel();
    _nextChapterPreloadTimer = null;
  }

  /// 获取图片尺寸（延迟加载，避免阻塞UI）
  Future<Size> _getImageSize(String imageUrl, int index) async {
    PerformanceMonitor.startTimer('getImageSize');

    if (_imageSizes.containsKey(index)) {
      PerformanceMonitor.stopTimer('getImageSize');
      return _imageSizes[index] ?? Size(1000, 1500); // 提供默认值避免空指针
    }

    // 延迟加载，避免在页面切换时阻塞UI
    await Future.delayed(const Duration(milliseconds: 10));

    try {
      final Completer<Size> completer = Completer<Size>();
      final Image image = Image.network(imageUrl);

      image.image.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener(
          (ImageInfo info, bool _) {
            final Size size = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
            _imageSizes[index] = size;
            completer.complete(size);
          },
          onError: (exception, stackTrace) {
            // 获取尺寸失败时使用默认值
            final Size defaultSize = Size(1000, 1500);
            _imageSizes[index] = defaultSize;
            completer.complete(defaultSize);
          },
        ),
      );

      // 设置超时，避免长时间等待
      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          final Size defaultSize = Size(1000, 1500);
          _imageSizes[index] = defaultSize;
          return defaultSize;
        },
      );

      PerformanceMonitor.stopTimer('getImageSize');
      return result;
    } catch (e) {
      // 如果无法获取尺寸，返回默认值
      final Size defaultSize = Size(1000, 1500); // 假设默认纵向图片
      _imageSizes[index] = defaultSize;
      PerformanceMonitor.recordError('getImageSize');
      PerformanceMonitor.stopTimer('getImageSize');
      return defaultSize;
    }
  }

  /// 检查图片索引是否有效
  bool _isValidImageIndex(int index) {
    return index >= 0 && index < _uiState.imageUrls.length;
  }

  /// 检查图片是否为横向（宽大于高）
  bool _isLandscapeImage(int index) {
    // 安全检查：确保索引在有效范围内
    if (!_isValidImageIndex(index)) {
      return false;
    }

    if (_imageSizes.containsKey(index)) {
      final Size? size = _imageSizes[index];
      if (size != null) {
        return size.width > size.height;
      }
    }

    // 如果尺寸信息尚未获取，异步获取并返回默认值
    if (index < _uiState.imageUrls.length) {
      // 异步获取尺寸，不影响当前判断
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_imageSizes.containsKey(index)) {
          _getImageSize(_uiState.imageUrls[index], index);
        }
      });
    }

    return false; // 默认认为是纵向图片
  }

  /// 计算页面索引（考虑宽高比和移位功能）
  int _getPageCount() {
    if (!_uiState.dualPageMode) {
      return _uiState.imageUrls.length;
    }

    // 安全检查：如果图片列表为空，返回0
    if (_uiState.imageUrls.isEmpty) {
      return 0;
    }

    // 如果启用双页模式，我们需要根据图片宽高比来决定
    int pageCount = 0;
    int i = _uiState.shiftDoublePage ? 1 : 0; // 移位功能：从第1张图片开始配对

    while (i < _uiState.imageUrls.length) {
      // 检查当前图片是否为横向
      if (_isLandscapeImage(i)) {
        // 横向图片单独显示一页
        pageCount++;
        i++;
      } else {
        // 纵向图片尝试双页显示
        pageCount++;
        // 确保不会超出数组边界
        if (i + 1 < _uiState.imageUrls.length) {
          i += 2; // 跳过下一张图片，因为它和当前图片组成双页
        } else {
          i++; // 如果是最后一张图片，只增加1
        }
      }
    }

    // 如果启用了移位功能，需要检查是否有多余的单页
    if (_uiState.shiftDoublePage && _uiState.imageUrls.length > 0) {
      // 检查第0张图片是否单独显示
      if (!_isLandscapeImage(0)) {
        pageCount++;
      }
    }

    return pageCount;
  }

  /// 根据页面索引获取图片索引（考虑宽高比和移位功能）
  List<int> _getImageIndicesForPage(int pageIndex) {
    if (!_uiState.dualPageMode) {
      // 安全检查：确保pageIndex在有效范围内
      if (!_isValidImageIndex(pageIndex)) {
        return [];
      }
      return [pageIndex];
    }

    // 安全检查：如果图片列表为空，返回空列表
    if (_uiState.imageUrls.isEmpty) {
      return [];
    }

    // 计算总页数，确保pageIndex在有效范围内
    int totalPageCount = _getPageCount();
    if (pageIndex < 0 || pageIndex >= totalPageCount) {
      return [];
    }

    // 处理移位功能的特殊情况
    if (_uiState.shiftDoublePage && pageIndex == 0) {
      // 第0页显示第0张图片（单独显示）
      return [0];
    }

    // 遍历直到找到指定页面索引对应的图片
    int currentPageIndex = _uiState.shiftDoublePage ? 1 : 0; // 移位功能：从第1页开始
    int imageIndex = _uiState.shiftDoublePage ? 1 : 0; // 移位功能：从第1张图片开始配对

    while (imageIndex < _uiState.imageUrls.length && currentPageIndex < pageIndex) {
      if (_isLandscapeImage(imageIndex)) {
        // 横向图片单独显示一页
        imageIndex++;
      } else {
        // 纵向图片双页显示
        // 确保不会超出数组边界
        if (imageIndex + 1 < _uiState.imageUrls.length) {
          imageIndex += 2;
        } else {
          imageIndex++;
        }
      }
      currentPageIndex++;
    }

    // 安全检查：确保imageIndex在有效范围内
    if (imageIndex >= _uiState.imageUrls.length) {
      // 返回最后一张或两张图片的索引
      if (_uiState.imageUrls.length > 0) {
        if (_isLandscapeImage(_uiState.imageUrls.length - 1)) {
          return [_uiState.imageUrls.length - 1];
        } else {
          if (_uiState.imageUrls.length >= 2 && !_isLandscapeImage(_uiState.imageUrls.length - 2)) {
            return [_uiState.imageUrls.length - 2, _uiState.imageUrls.length - 1];
          } else {
            return [_uiState.imageUrls.length - 1];
          }
        }
      }
      return [];
    }

    // 返回当前页面应该显示的图片索引
    if (_isLandscapeImage(imageIndex)) {
      return [imageIndex];
    } else {
      // 检查是否还有下一张图片用于双页显示
      if (imageIndex + 1 < _uiState.imageUrls.length && !_isLandscapeImage(imageIndex + 1)) {
        return [imageIndex, imageIndex + 1];
      } else {
        return [imageIndex];
      }
    }
  }

  /// 根据图片索引计算页面索引（考虑宽高比和移位功能）
  int _getPageIndexOfImage(int imageIndex) {
    if (!_uiState.dualPageMode) {
      // 安全检查：确保imageIndex在有效范围内
      if (!_isValidImageIndex(imageIndex)) {
        return 0;
      }
      return imageIndex;
    }

    // 安全检查：如果图片列表为空，返回0
    if (_uiState.imageUrls.isEmpty) {
      return 0;
    }

    // 安全检查：确保imageIndex在有效范围内
    if (!_isValidImageIndex(imageIndex)) {
      return 0;
    }

    // 处理移位功能的特殊情况
    if (_uiState.shiftDoublePage && imageIndex == 0) {
      // 第0张图片在第0页单独显示
      return 0;
    }

    int pageIndex = _uiState.shiftDoublePage ? 1 : 0; // 移位功能：从第1页开始
    int i = _uiState.shiftDoublePage ? 1 : 0; // 移位功能：从第1张图片开始配对

    while (i < imageIndex) {
      if (_isLandscapeImage(i)) {
        // 横向图片单独一页
        pageIndex++;
        i++;
      } else {
        // 纵向图片双页显示
        pageIndex++;
        // 确保不会超出数组边界
        if (i + 1 < _uiState.imageUrls.length) {
          i += 2;
        } else {
          i++;
        }
      }
    }

    if (i == imageIndex) {
      return pageIndex;
    } else {
      // 如果i > imageIndex，说明imageIndex是双页中的第二张
      // 在这种情况下，它和前一张图片在同一页面
      return pageIndex;
    }
  }


  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_config.autoHideControlsDelay, () {
      if (mounted && _uiState.showControls) {
        _hideControls();
      }
    });
  }

  void _startProgressSaveTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveReadingProgress();
    });
  }

  /// 启动内存清理定时器
  void _startMemoryCleanupTimer() {
    _memoryCleanupTimer?.cancel();
    _memoryCleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performMemoryCleanup();
    });
  }

  /// 执行内存清理操作
  void _performMemoryCleanup() {
    if (!mounted) return;

    // 清理过远的预加载页面
    _cleanupDistantPreloadedPages();

    // 清理过期的图片尺寸缓存
    _cleanupExpiredImageSizes();
  }

  /// 清理过期的图片尺寸缓存
  void _cleanupExpiredImageSizes() {
    // 只保留当前页面附近一定范围内的尺寸缓存
    final cleanupThreshold = _preloadRange * 3;

    _imageSizes.removeWhere((index, size) {
      final distance = (index - _uiState.currentPage).abs();
      return distance > cleanupThreshold;
    });
  }

  /// 显示SnackBar提示
  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _hideControls() {
    setState(() {
      _uiState = _uiState.copyWith(showControls: false);
    });
    _controlsAnimationController.reverse();
  }

  void _showControlsTemporarily() {
    setState(() {
      _uiState = _uiState.copyWith(showControls: true);
    });
    _controlsAnimationController.forward();
    _startHideTimer();
  }

  void _handleAction(String action) {
    switch (action) {
      case 'previous_page':
        _previousPage();
        break;
      case 'next_page':
        _nextPage();
        break;
      case 'toggle_ui':
        _toggleUI();
        break;
      case 'menu':
        _showSettings();
        break;
      case 'settings':
        _showSettings();
        break;
      case 'zoom_in':
        // 捏合放大已经通过 onZoomChanged 处理
        break;
      case 'zoom_out':
        // 捏合缩小已经通过 onZoomChanged 处理
        break;
    }
  }

  void _toggleUI() {
    HapticFeedbackManager.lightImpact();
    if (_uiState.showControls) {
      _hideControls();
    } else {
      _showControlsTemporarily();
    }
  }

  /// 重置缩放状态
  void _resetZoom() {
    // 取消缩放重置计时器
    _gestureHandler?.cancelZoomReset();

    setState(() {
      _uiState = _uiState.copyWith(
        currentScale: 1.0,
        panOffset: Offset.zero,
        cumulativePanOffset: Offset.zero,
      );
    });
  }


  void _previousPage() {
    PerformanceMonitor.startTimer('pageSwitch');

    if (_uiState.dualPageMode) {
      // 智能双页模式
      int currentPageIndex = _getPageIndexOfImage(_uiState.currentPage);

      if (currentPageIndex > 0) {
        HapticFeedbackManager.selectionClick();
        final config = PageAnimationManager().getTapAnimationConfig();
        if (_pageController.hasClients) {
          _pageController.previousPage(
            duration: config.duration,
            curve: config.curve,
          );
        }
        PerformanceMonitor.recordPageSwitch(currentPageIndex, currentPageIndex - 1, config.duration);
      }
    } else {
      // 单页模式
      if (_uiState.currentPage > 0) {
        HapticFeedbackManager.selectionClick();
        final config = PageAnimationManager().getTapAnimationConfig();
        if (_pageController.hasClients) {
          _pageController.previousPage(
            duration: config.duration,
            curve: config.curve,
          );
        }
        PerformanceMonitor.recordPageSwitch(_uiState.currentPage, _uiState.currentPage - 1, config.duration);
      }
    }

    PerformanceMonitor.stopTimer('pageSwitch');
  }

  void _nextPage() {
    PerformanceMonitor.startTimer('pageSwitch');

    if (_uiState.dualPageMode) {
      // 智能双页模式
      int currentPageIndex = _getPageIndexOfImage(_uiState.currentPage);
      int pageCount = _getPageCount();

      if (currentPageIndex < pageCount - 1) {
        HapticFeedbackManager.selectionClick();
        final config = PageAnimationManager().getTapAnimationConfig();
        if (_pageController.hasClients) {
          _pageController.nextPage(
            duration: config.duration,
            curve: config.curve,
          );
        }
        PerformanceMonitor.recordPageSwitch(currentPageIndex, currentPageIndex + 1, config.duration);
      } else {
        // 到达章节末尾，自动标记为已阅读并显示过渡画面
        _markCurrentChapterAsRead();
        _showChapterTransition();
      }
    } else {
      // 单页模式
      if (_uiState.currentPage < _uiState.imageUrls.length - 1) {
        HapticFeedbackManager.selectionClick();
        final config = PageAnimationManager().getTapAnimationConfig();
        if (_pageController.hasClients) {
          _pageController.nextPage(
            duration: config.duration,
            curve: config.curve,
          );
        }
        PerformanceMonitor.recordPageSwitch(_uiState.currentPage, _uiState.currentPage + 1, config.duration);
      } else {
        // 到达章节末尾，自动标记为已阅读并显示过渡画面
        _markCurrentChapterAsRead();
        _showChapterTransition();
      }
    }

    PerformanceMonitor.stopTimer('pageSwitch');
  }

  /// 滑动翻页
  void _swipePage(bool isForward, Offset velocity) {
    PerformanceMonitor.startTimer('swipePage');

    if (_uiState.dualPageMode) {
      // 智能双页模式
      int currentPageIndex = _getPageIndexOfImage(_uiState.currentPage);
      int pageCount = _getPageCount();

      if (isForward) {
        if (currentPageIndex < pageCount - 1) {
          final config = PageAnimationManager().getSwipeAnimationConfig(velocity, true);
          if (_pageController.hasClients) {
            _pageController.nextPage(
              duration: config.duration,
              curve: config.curve,
            );
          }
          PerformanceMonitor.recordPageSwitch(currentPageIndex, currentPageIndex + 1, config.duration);
        }
      } else {
        if (currentPageIndex > 0) {
          final config = PageAnimationManager().getSwipeAnimationConfig(velocity, false);
          if (_pageController.hasClients) {
            _pageController.previousPage(
              duration: config.duration,
              curve: config.curve,
            );
          }
          PerformanceMonitor.recordPageSwitch(currentPageIndex, currentPageIndex - 1, config.duration);
        }
      }
    } else {
      // 单页模式
      if (isForward) {
        if (_uiState.currentPage < _uiState.imageUrls.length - 1) {
          final config = PageAnimationManager().getSwipeAnimationConfig(velocity, true);
          if (_pageController.hasClients) {
            _pageController.nextPage(
              duration: config.duration,
              curve: config.curve,
            );
          }
          PerformanceMonitor.recordPageSwitch(_uiState.currentPage, _uiState.currentPage + 1, config.duration);
        }
      } else {
        if (_uiState.currentPage > 0) {
          final config = PageAnimationManager().getSwipeAnimationConfig(velocity, false);
          if (_pageController.hasClients) {
            _pageController.previousPage(
              duration: config.duration,
              curve: config.curve,
            );
          }
          PerformanceMonitor.recordPageSwitch(_uiState.currentPage, _uiState.currentPage - 1, config.duration);
        }
      }
    }

    PerformanceMonitor.stopTimer('swipePage');
  }


  /// 显示章节过渡画面
  Future<void> _showChapterTransition() async {
    final nextChapterIndex = _uiState.currentChapterIndex + 1;

    // 检查是否有下一章
    if (nextChapterIndex >= widget.chapters.length) {
      // 没有下一章，显示提示并处理连续点击退出逻辑
      _handleLastChapterReached();
      return;
    }

    // 有下一章，显示过渡画面并自动跳转
    final nextChapter = widget.chapters[nextChapterIndex];
    _showTransitionDialog(
      '正在前往下一章',
      '第${nextChapter.number}话: ${nextChapter.title}',
      onConfirm: () => _loadNextChapter(nextChapterIndex),
    );
  }

  /// 显示过渡对话框
  void _showTransitionDialog(String title, String message, {VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                onConfirm != null ? Icons.arrow_forward : Icons.check,
                color: Color(0xFFFF6B6B),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: onConfirm != null
            ? [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF6B6B),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('前往下一章'),
                ),
              ]
            : [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // 关闭弹窗
                    Navigator.of(context).pop(); // 退出阅读器
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF6B6B),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('退出观看'),
                ),
              ],
      ),
    );
  }

  /// 加载下一章节
  Future<void> _loadNextChapter(int nextChapterIndex) async {
    if (_uiState.isLoadingNextChapter) {
      return;
    }

    setState(() {
      _uiState = _uiState.copyWith(isLoadingNextChapter: true);
    });

    try {
      final nextChapter = widget.chapters[nextChapterIndex];

      // 加载新章节图片
      final apiImageFiles = await MangaApiService.getChapterImageFiles(
        widget.manga.id,
        nextChapter.id,
      );

      if (!mounted) {
        setState(() {
          _uiState = _uiState.copyWith(isLoadingNextChapter: false);
        });
        return;
      }

      if (apiImageFiles.isNotEmpty) {
        List<String> newImageUrls = [];
        for (String fileName in apiImageFiles) {
          newImageUrls.add(
            MangaApiService.getChapterImageUrl(
              widget.manga.id,
              nextChapter.id,
              fileName,
            ),
          );
        }

        setState(() {
          _uiState = _uiState.copyWith(
            currentChapterIndex: nextChapterIndex,
            currentPage: 0,
            imageUrls: newImageUrls,
            isLoadingNextChapter: false,
          );
        });

        // 重置页面控制器
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }

        // 清理章节切换时的资源
        _cleanupChapterResources();

        // 立即预加载新章节的图片
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preloadNearbyPages();   // 预加载新章节的图片
        });

        // 保存新章节的阅读进度
        _saveReadingProgress();

        _showSnackBar('已切换到第${nextChapter.number}章: ${nextChapter.title}');
      } else {
        setState(() {
          _uiState = _uiState.copyWith(isLoadingNextChapter: false);
        });
        _showSnackBar('无法获取下一章图片列表');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uiState = _uiState.copyWith(isLoadingNextChapter: false);
        });
      }
      _showSnackBar('加载下一章失败');
    }
  }

  
  void _showSettings() {
    HapticFeedbackManager.mediumImpact();
    _settingsAnimationController.forward();
  }

  /// 处理到达最后一章的逻辑
  void _handleLastChapterReached() {
    if (!_isLastChapterDialogShown) {
      // 第一次到达最后一章，显示弹窗
      _isLastChapterDialogShown = true;
      _showTransitionDialog('已是最后一章', '您已经阅读完所有章节');
    } else {
      // 弹窗已经显示过，直接退出观看
      Navigator.of(context).pop();
    }
  }

  /// 设置音量键监听（使用 MethodChannel 与 Android 通信）
  void _setupVolumeKeyListener() {
    if (_isChannelListenerSetup || !_volumeButtonNavigationEnabled) {
      return;
    }

    // 设置方法调用处理器
    EnhancedReaderPage.platform.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onVolumeKeyPressed') {
        final String key = call.arguments['key'];

        if (key == 'volume_up') {
          _previousPage();
        } else if (key == 'volume_down') {
          _nextPage();
        }
      }
    });

    _isChannelListenerSetup = true;
  }

  /// 启用或禁用音量键拦截
  Future<void> _enableVolumeKeyInterception(bool enabled) async {
    try {
      await EnhancedReaderPage.platform.invokeMethod('setVolumeKeyInterception', {
        'enabled': enabled,
      });
    } catch (e) {
      // 设置音量键拦截失败
    }
  }


  @override
  Future<bool> didPopRoute() async {
    // 这个方法在Android上会被调用，可以用于处理系统按键
    return false; // 返回false表示不处理，让系统继续处理
  }

  /// 安全清理定时器
  void _safeCancelTimer(Timer? timer) {
    try {
      timer?.cancel();
    } catch (e) {
      print('定时器清理异常: $e');
      // 忽略定时器清理异常，避免应用崩溃
    }
  }

  @override
  void dispose() {
    // 移除消息处理器，防止内存泄漏和崩溃
    EnhancedReaderPage.platform.setMethodCallHandler(null);

    // 移除WidgetsBinding观察者
    WidgetsBinding.instance.removeObserver(this);

    // 退出时保存最终进度
    _saveReadingProgress();

    // 禁用音量键拦截
    _enableVolumeKeyInterception(false);

    // 清理手势处理器
    _gestureHandler?.dispose();

    // 清理所有控制器
    _pageController.dispose();
    _scrollController.dispose();
    _settingsAnimationController.dispose();
    _controlsAnimationController.dispose();
    _focusNode.dispose();

    // 安全清理所有定时器
    _safeCancelTimer(_hideTimer);
    _safeCancelTimer(_progressSaveTimer);
    _safeCancelTimer(_nextChapterPreloadTimer);
    _safeCancelTimer(_memoryCleanupTimer);

    // 清理预加载资源
    _preloadedPages.clear();
    _imageSizes.clear();

    // 恢复系统UI
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (e) {
      print('恢复系统UI模式异常: $e');
      // 忽略系统UI设置异常，避免应用崩溃
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用错误边界包装整个阅读器，防止崩溃
    return ErrorBoundary(
      child: _buildReaderContent(),
    );
  }

  /// 构建阅读器内容
  Widget _buildReaderContent() {
    if (_uiState.isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
              ),
              const SizedBox(height: 20),
              Text(
                '正在加载章节...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_uiState.errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Color(0xFFFF6B6B),
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                _uiState.errorMessage!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadChapterImages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                ),
                child: Text('重试'),
              ),
            ],
          ),
        ),
      );
    }


    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: GestureDetector(
          onTap: () {
            // 如果设置面板打开，点击外部区域关闭它
            if (_settingsAnimationController.value > 0.5) {
              _settingsAnimationController.reverse();
            }
          },
          child: EnhancedReaderGestureDetector(
            config: _config,
            onAction: _handleAction,
            onZoomChanged: (scale) {
              setState(() {
                _uiState = _uiState.copyWith(currentScale: scale);
              });
            },
            onPanChanged: (offset) {
              setState(() {
                // 如果接收到的是 Offset.zero，表示缩放结束，重置累积偏移量
                Offset newCumulativePanOffset;
                if (offset == Offset.zero) {
                  newCumulativePanOffset = Offset.zero;
                } else {
                  // 累积平移偏移量，实现平滑拖动
                  newCumulativePanOffset = _uiState.cumulativePanOffset + offset;
                }
                _uiState = _uiState.copyWith(
                  panOffset: newCumulativePanOffset,
                  cumulativePanOffset: newCumulativePanOffset,
                );
              });
            },
            onSwipePage: (isForward, velocity) {
              _swipePage(isForward, velocity);
            },
            onGestureHandlerCreated: (gestureHandler) {
              _gestureHandler = gestureHandler;
            },
            child: Stack(
              children: [
                // 主阅读区域
                _uiState.readingDirection == ReadingDirection.vertical ||
                    _uiState.readingDirection == ReadingDirection.webtoon
                    ? _buildVerticalReader()
                    : _buildHorizontalReader(),


                // 顶部控制栏
                if (_uiState.showControls)
                  _buildTopControls(),

                // 底部控制栏
                if (_uiState.showControls)
                  _buildBottomControls(),


                // 设置面板
                _buildSettingsPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalReader() {
    if (_uiState.dualPageMode && _uiState.imageUrls.isNotEmpty) {
      // 智能双页模式：根据图片宽高比决定显示方式
      int pageCount = _getPageCount();

      return PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          // 页面切换时重置缩放状态
          _resetZoom();

          // 获取当前页面显示的图片索引
          List<int> imageIndices = _getImageIndicesForPage(index);
          if (imageIndices.isNotEmpty) {
            setState(() {
              _uiState = _uiState.copyWith(currentPage: imageIndices.first);
            });
          }

          _preloadNearbyPages();
          // 页面切换时立即保存进度
          _saveReadingProgress();
          if (_uiState.showControls) {
            _startHideTimer();
          }

          // 检测是否到达章节末尾（通过滑动翻页时）
          if (index == pageCount - 1) {  // 最后一个页面
            // 到达章节末尾，自动标记为已阅读
            _markCurrentChapterAsRead();
            // 延迟一小段时间再显示过渡画面，避免与滑动动画冲突
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted && index == pageCount - 1) {
                _showChapterTransition();
              }
            });
          }
        },
        itemCount: pageCount,
        reverse: _uiState.readingDirection == ReadingDirection.rightToLeft,
        itemBuilder: (context, index) {
          return _buildSmartPage(_uiState.imageUrls, index);
        },
      );
    } else {
      // 单页模式
      return PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          // 页面切换时重置缩放状态
          _resetZoom();
          setState(() {
            _uiState = _uiState.copyWith(currentPage: index);
          });
          _preloadNearbyPages();
          // 页面切换时立即保存进度
          _saveReadingProgress();
          if (_uiState.showControls) {
            _startHideTimer();
          }

          // 检测是否到达章节末尾（通过滑动翻页时）
          if (index == _uiState.imageUrls.length - 1) {
            // 到达章节末尾，自动标记为已阅读
            _markCurrentChapterAsRead();
            // 延迟一小段时间再显示过渡画面，避免与滑动动画冲突
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted && _uiState.currentPage == _uiState.imageUrls.length - 1) {
                _showChapterTransition();
              }
            });
          }
        },
        itemCount: _uiState.imageUrls.length,
        reverse: _uiState.readingDirection == ReadingDirection.rightToLeft,
        itemBuilder: (context, index) {
          return _buildImagePage(_uiState.imageUrls[index]);
        },
      );
    }
  }

  Widget _buildVerticalReader() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          // 计算当前页面
          final screenHeight = MediaQuery.of(context).size.height;
          final currentPage = (notification.metrics.pixels / screenHeight).floor().clamp(0, _uiState.imageUrls.length - 1);

          if (_uiState.currentPage != currentPage) {
            // 页面切换时重置缩放状态
            _resetZoom();
            setState(() {
              _uiState = _uiState.copyWith(currentPage: currentPage);
            });
            // 滚动页面切换时保存进度
            _saveReadingProgress();

            // 检测是否到达章节末尾（垂直滚动模式）
            if (currentPage == _uiState.imageUrls.length - 1) {
              // 到达章节末尾，自动标记为已阅读
              _markCurrentChapterAsRead();
              // 延迟一小段时间再显示过渡画面
              Future.delayed(Duration(milliseconds: 500), () {
                if (mounted && _uiState.currentPage == _uiState.imageUrls.length - 1) {
                  _showChapterTransition();
                }
              });
            }
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.vertical,
        itemCount: _uiState.imageUrls.length,
        itemBuilder: (context, index) {
          return _buildImagePage(_uiState.imageUrls[index]);
        },
      ),
    );
  }

  Widget _buildSmartPage(List<String> imageUrls, int pageIndex) {
    List<int> imageIndices = _getImageIndicesForPage(pageIndex);

    // 如果图片索引列表为空，显示错误页面
    if (imageIndices.isEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            '页面不存在',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // 如果只有一个图片索引，或者第一个图片是横向的，则只显示一张图片
    if (imageIndices.length == 1 || _isLandscapeImage(imageIndices.first)) {
      int imageIndex = imageIndices.first;
      if (_isValidImageIndex(imageIndex)) {
        return _buildImagePage(imageUrls[imageIndex]);
      } else {
        return Container(
          color: Colors.black,
          child: Center(
            child: Text(
              '页面不存在',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } else {
      // 显示双页（两个纵向图片并排）
      return _buildDualPageSmart(imageUrls, imageIndices);
    }
  }


  Widget _buildImagePage(String imageUrl) {
    return Container(
      color: Colors.black,
      child: Transform.scale(
        scale: _uiState.currentScale,
        child: Transform.translate(
          offset: _uiState.panOffset,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Color(0xFFFF6B6B),
                      size: 50,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '图片加载失败',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDualPageSmart(List<String> imageUrls, List<int> imageIndices) {
    // 确保有两个图片索引用于双页显示
    if (imageIndices.length < 2) {
      if (imageIndices.isNotEmpty) {
        int singleImageIndex = imageIndices.first;
        if (_isValidImageIndex(singleImageIndex)) {
          return _buildImagePage(imageUrls[singleImageIndex]);
        }
      }
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            '页面不存在',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    int leftImageIndex = imageIndices[0];
    int rightImageIndex = imageIndices[1];

    // 检查是否有左右两页的图片
    bool hasLeftImage = _isValidImageIndex(leftImageIndex);
    bool hasRightImage = _isValidImageIndex(rightImageIndex);

    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double containerWidth = constraints.maxWidth;
          double containerHeight = constraints.maxHeight;

          return Stack(
            children: [
              // 第一页 - 在容器的左半部分
              if (hasRightImage)
                Positioned(
                  left: 0,
                  top: 0,
                  width: containerWidth / 2 - 0.5, // 减少0.5像素确保精确对齐
                  height: containerHeight,
                  child: CachedNetworkImage(
                    imageUrl: imageUrls[rightImageIndex],
                    fit: BoxFit.contain,
                    alignment: Alignment.centerRight, // 调整图片对齐方式
                    placeholder: (context, url) => Container(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Color(0xFFFF6B6B),
                              size: 50,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '图片加载失败',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  left: 0,
                  top: 0,
                  width: containerWidth / 2 - 0.5,
                  height: containerHeight,
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: Text(
                        '页面不存在',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),

              // 第二页 - 在容器的右半部分
              if (hasLeftImage)
                Positioned(
                  left: containerWidth / 2 + 0.5, // 加上0.5像素缝隙
                  top: 0,
                  width: containerWidth / 2 - 0.5, // 减少0.5像素确保精确对齐
                  height: containerHeight,
                  child: CachedNetworkImage(
                    imageUrl: imageUrls[leftImageIndex],
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft, // 调整图片对齐方式
                    placeholder: (context, url) => Container(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Color(0xFFFF6B6B),
                              size: 50,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '图片加载失败',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  left: containerWidth / 2 + 0.5,
                  top: 0,
                  width: containerWidth / 2 - 0.5,
                  height: containerHeight,
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: Text(
                        '页面不存在',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),

              // 添加1像素的细线作为页面分隔（可选，如果需要的话）
              Positioned(
                left: containerWidth / 2 - 0.5, // 在两页之间
                top: 0,
                width: 1,  // 1像素宽的分隔线
                height: containerHeight,
                child: Container(
                  color: Colors.black, // 与背景色一致，几乎不可见
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDualPage(List<String> imageUrls, int pageIndex) {
    // 计算要显示的图片索引
    int rightImageIndex = pageIndex * 2;  // 右页（在从右到左阅读中是较小的页码）
    int leftImageIndex = pageIndex * 2 + 1;  // 左页（在从右到左阅读中是较大的页码）

    // 检查是否有左右两页的图片
    bool hasLeftImage = leftImageIndex < imageUrls.length;
    bool hasRightImage = rightImageIndex < imageUrls.length;

    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double containerWidth = constraints.maxWidth;
          double containerHeight = constraints.maxHeight;

          return Stack(
            children: [
              // 第一页 - 在容器的左半部分
              if (hasRightImage)
                Positioned(
                  left: 0,
                  top: 0,
                  width: containerWidth / 2 - 0.5, // 减少0.5像素确保精确对齐
                  height: containerHeight,
                  child: CachedNetworkImage(
                    imageUrl: imageUrls[rightImageIndex],
                    fit: BoxFit.contain,
                    alignment: Alignment.centerRight, // 调整图片对齐方式
                    placeholder: (context, url) => Container(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Color(0xFFFF6B6B),
                              size: 50,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '图片加载失败',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  left: 0,
                  top: 0,
                  width: containerWidth / 2 - 0.5,
                  height: containerHeight,
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: Text(
                        '页面不存在',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),

              // 第二页 - 在容器的右半部分
              if (hasLeftImage)
                Positioned(
                  left: containerWidth / 2 + 0.5, // 加上0.5像素缝隙
                  top: 0,
                  width: containerWidth / 2 - 0.5, // 减少0.5像素确保精确对齐
                  height: containerHeight,
                  child: CachedNetworkImage(
                    imageUrl: imageUrls[leftImageIndex],
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft, // 调整图片对齐方式
                    placeholder: (context, url) => Container(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Color(0xFFFF6B6B),
                              size: 50,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '图片加载失败',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  left: containerWidth / 2 + 0.5,
                  top: 0,
                  width: containerWidth / 2 - 0.5,
                  height: containerHeight,
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: Text(
                        '页面不存在',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),

              // 添加1像素的细线作为页面分隔（可选，如果需要的话）
              Positioned(
                left: containerWidth / 2 - 0.5, // 在两页之间
                top: 0,
                width: 1,  // 1像素宽的分隔线
                height: containerHeight,
                child: Container(
                  color: Colors.black, // 与背景色一致，几乎不可见
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopControls() {
    return AnimatedBuilder(
      animation: _controlsAnimationController,
      builder: (context, child) {
        return Positioned(
          top: -50 * (1 - _controlsAnimationController.value),
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.manga.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '第${_getCurrentChapter().number}章: ${_getCurrentChapter().title}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return AnimatedBuilder(
      animation: _controlsAnimationController,
      builder: (context, child) {
        return Positioned(
          bottom: -80 * (1 - _controlsAnimationController.value),
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              top: 16,
            ),
            child: Column(
              children: [
                // 进度条
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Color(0xFFFF6B6B),
                    inactiveTrackColor: Colors.grey[600],
                    thumbColor: Color(0xFFFF6B6B),
                    overlayColor: Color(0xFFFF6B6B).withOpacity(0.2),
                    trackHeight: 4.0,
                  ),
                  child: _uiState.dualPageMode
                    ? Slider(
                        value: _getPageIndexOfImage(_uiState.currentPage).toDouble(),
                        min: 0,
                        max: (_getPageCount() - 1).toDouble(),
                        onChanged: (value) {
                          int newPageIndex = value.round();

                          // 找到新页面对应的图片索引
                          List<int> imageIndices = _getImageIndicesForPage(newPageIndex);
                          if (imageIndices.isNotEmpty) {
                            int newPage = imageIndices.first;

                            setState(() {
                              _uiState = _uiState.copyWith(currentPage: newPage);
                            });

                            _pageController.animateToPage(
                              newPageIndex,
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                      )
                    : Slider(
                        value: _uiState.currentPage.toDouble(),
                        min: 0,
                        max: (_uiState.imageUrls.length - 1).toDouble(),
                        onChanged: (value) {
                          int newPage = value.round();
                          setState(() {
                            _uiState = _uiState.copyWith(currentPage: newPage);
                          });
                          _pageController.animateToPage(
                            newPage,
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                ),
                const SizedBox(height: 8),
                // 页面信息和控制按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _uiState.dualPageMode
                        ? '第 ${_getPageIndexOfImage(_uiState.currentPage) + 1}/${_getPageCount()} 页 (${_uiState.shiftDoublePage ? '移位双页' : '智能双页'}模式)'
                        : '第 ${_uiState.currentPage + 1}/${_uiState.imageUrls.length} 页',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.settings,
                            color: Colors.white,
                          ),
                          onPressed: _showSettings,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  


  Widget _buildSettingsPanel() {
    return AnimatedBuilder(
      animation: _settingsAnimationController,
      builder: (context, child) {
        return Positioned(
          left: -400 * (1 - _settingsAnimationController.value),
          top: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () {
              // 阻止事件冒泡，防止点击设置面板时关闭它
            },
            child: Container(
            width: 350,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.95),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '阅读设置',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => _settingsAnimationController.reverse(),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  '阅读',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10),
                Column(
                  children: [
                    _buildReadingDirectionOption(
                      '从左到右',
                      ReadingDirection.rightToLeft,
                    ),
                    SizedBox(height: 8),
                    _buildReadingDirectionOption(
                      '从右到左',
                      ReadingDirection.leftToRight,
                    ),
                    SizedBox(height: 8),
                    _buildReadingDirectionOption(
                      '垂直滚动',
                      ReadingDirection.vertical,
                    ),
                    SizedBox(height: 8),
                    _buildReadingDirectionOption(
                      '网漫模式',
                      ReadingDirection.webtoon,
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  '双页模式',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10),
                _buildDualPageOption(),
                SizedBox(height: 10),
                if (_uiState.dualPageMode)
                  _buildShiftDoublePageOption(),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  /// 构建双页模式选项
  Widget _buildDualPageOption() {
    return SwitchListTile(
      title: Text(
        '启用双页模式',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      value: _uiState.dualPageMode,
      onChanged: (bool value) {
        setState(() {
          _uiState = _uiState.copyWith(dualPageMode: value);
          // 如果关闭双页模式，同时关闭移位功能
          if (!value) {
            _uiState = _uiState.copyWith(shiftDoublePage: false);
          }
          _config = ReadingGestureConfig(
            readingDirection: _uiState.readingDirection,
            tapToZoom: _config.tapToZoom,
            volumeButtonNavigation: _config.volumeButtonNavigation,
            fullscreenOnTap: _config.fullscreenOnTap,
            keepScreenOn: _config.keepScreenOn,
            autoHideControlsDelay: _config.autoHideControlsDelay,
            enableImmersiveMode: _config.enableImmersiveMode,
            dualPageMode: value,
            shiftDoublePage: _uiState.shiftDoublePage,
            gestureActions: _config.gestureActions,
          );
        });
        HapticFeedbackManager.lightImpact();
        _showSnackBar(value ? '已启用双页模式' : '已禁用双页模式');
      },
      activeColor: Color(0xFFFF6B6B),
      activeTrackColor: Color(0xFFFF6B6B).withOpacity(0.3),
    );
  }

  /// 构建移位双页选项
  Widget _buildShiftDoublePageOption() {
    return SwitchListTile(
      title: Text(
        '启用页面移位',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        '调整页面配对起始位置',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 12,
        ),
      ),
      value: _uiState.shiftDoublePage,
      onChanged: (bool value) {
        setState(() {
          _uiState = _uiState.copyWith(shiftDoublePage: value);
          _config = ReadingGestureConfig(
            readingDirection: _uiState.readingDirection,
            tapToZoom: _config.tapToZoom,
            volumeButtonNavigation: _config.volumeButtonNavigation,
            fullscreenOnTap: _config.fullscreenOnTap,
            keepScreenOn: _config.keepScreenOn,
            autoHideControlsDelay: _config.autoHideControlsDelay,
            enableImmersiveMode: _config.enableImmersiveMode,
            dualPageMode: _uiState.dualPageMode,
            shiftDoublePage: value,
            gestureActions: _config.gestureActions,
          );
        });
        HapticFeedbackManager.lightImpact();
        _showSnackBar(value ? '已启用页面移位' : '已禁用页面移位');
      },
      activeColor: Color(0xFFFF6B6B),
      activeTrackColor: Color(0xFFFF6B6B).withOpacity(0.3),
    );
  }

  /// 构建阅读方向选项
  Widget _buildReadingDirectionOption(String title, ReadingDirection direction) {
    final isSelected = _uiState.readingDirection == direction;

    return GestureDetector(
      onTap: () {
        setState(() {
          _uiState = _uiState.copyWith(readingDirection: direction);
          _config = ReadingGestureConfig(
            readingDirection: direction,
            tapToZoom: _config.tapToZoom,
            volumeButtonNavigation: _config.volumeButtonNavigation,
            fullscreenOnTap: _config.fullscreenOnTap,
            keepScreenOn: _config.keepScreenOn,
            autoHideControlsDelay: _config.autoHideControlsDelay,
            enableImmersiveMode: _config.enableImmersiveMode,
            dualPageMode: _uiState.dualPageMode, // 保留双页模式设置
            shiftDoublePage: _uiState.shiftDoublePage, // 保留移位功能设置
            gestureActions: _config.gestureActions,
          );
        });
        HapticFeedbackManager.lightImpact();
        _showSnackBar('已切换到$title');
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFFF6B6B).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Color(0xFFFF6B6B) : Colors.grey[700] ?? Colors.grey,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? Color(0xFFFF6B6B) : Colors.grey[500],
              size: 20,
            ),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
