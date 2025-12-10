import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import '../services/reading_progress_service.dart';
import '../utils/reader_gestures.dart';
import '../utils/page_animation_manager.dart';
import '../utils/dual_page_utils.dart';
import 'dart:async';
import 'dart:math' as math;


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
  // 过渡页面标识
  static const String _transitionPageMarker = 'transition://chapter_end';

  // 基础控制器
  late PageController _pageController;
  late ScrollController _scrollController;

  // 阅读状态
  int _currentPage = 0;
  bool _showControls = true;
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _imageUrls = [];

  // 双页阅读状态
  DualPageConfig _dualPageConfig = DualPageConfig();
  List<PageGroup> _pageGroups = [];
  int _currentGroupIndex = 0;

  // 章节跳转状态
  int _currentChapterIndex = 0;
  bool _isLoadingNextChapter = false;

  // UI状态
  Timer? _hideTimer;
  bool _isInFullscreen = false; // ignore: unused_field
  bool _showSettingsPanel = false; // ignore: unused_field

  // 缩放和拖拽
  double _currentScale = 1.0;
  Offset _panOffset = Offset.zero;
  Offset _cumulativePanOffset = Offset.zero;

  // 配置
  late ReadingGestureConfig _config;
  ReadingDirection _readingDirection = ReadingDirection.rightToLeft;

  // 动画控制器
  late AnimationController _settingsAnimationController;
  late AnimationController _controlsAnimationController;

  // 预加载
  Set<int> _preloadedPages = <int>{};
  static const int _preloadRange = 5; // 增加预加载范围
  static const int _chapterEndPreloadThreshold = 3; // 章节末尾预加载阈值
  bool _isNearChapterEnd = false;
  Timer? _nextChapterPreloadTimer;

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
    super.initState();

    // 注册WidgetsBinding观察者
    WidgetsBinding.instance.addObserver(this);

    // 初始化配置
    _config = widget.initialConfig ?? ReadingGestureConfig();
    _readingDirection = _config.readingDirection;
    _volumeButtonNavigationEnabled = _config.volumeButtonNavigation;

    // 初始化焦点节点
    _focusNode = FocusNode();

    // 设置 MethodChannel 监听 - 关键！
    _setupVolumeKeyListener();

    // 启用音量键拦截
    _enableVolumeKeyInterception(true);

    // 初始化当前章节索引
    _currentChapterIndex = widget.chapters.indexWhere((chapter) => chapter.id == widget.chapter.id);
    if (_currentChapterIndex == -1) {
      _currentChapterIndex = 0;
    }

    // 初始化控制器
    _pageController = PageController(initialPage: _currentPage);
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
  }

  void _loadChapterImages() async {
    try {
      final apiImageFiles = await MangaApiService.getChapterImageFiles(
        widget.manga.id,
        widget.chapter.id,
      );

      if (apiImageFiles.isNotEmpty) {
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

        // 在章节末尾添加过渡页面
        imageUrls.add(_transitionPageMarker);

        setState(() {
          _imageUrls = imageUrls;
          _isLoading = false;
        });

        // 预加载附近页面
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preloadNearbyPages();
        });
      } else {
        setState(() {
          _errorMessage = "无法获取章节图片列表";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "加载章节失败: $e";
        _isLoading = false;
      });
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
    if (_currentChapterIndex >= 0 && _currentChapterIndex < widget.chapters.length) {
      return widget.chapters[_currentChapterIndex];
    }
    return widget.chapter;
  }

  /// 跳转到进度位置
  void _jumpToProgress() {
    if (_existingProgress == null) return;

    // 如果图片还没有加载完成，等待加载完成后再跳转
    if (_imageUrls.isEmpty) {
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

    while (_imageUrls.isEmpty && DateTime.now().difference(startTime) < maxWaitTime) {
      await Future.delayed(Duration(milliseconds: 100));
    }

    if (_imageUrls.isNotEmpty && mounted) {
      _performJumpToProgress();
    } else if (mounted) {
      _showSnackBar('图片加载超时，请重试');
    }
  }

  /// 执行实际的跳转逻辑
  void _performJumpToProgress() {
    if (_existingProgress == null || _imageUrls.isEmpty) return;

    final targetPage = _existingProgress!.currentPage.clamp(0, _imageUrls.length - 1);

    setState(() {
      _currentPage = targetPage;
    });

    if (_readingDirection == ReadingDirection.vertical ||
        _readingDirection == ReadingDirection.webtoon) {
      _scrollController.animateTo(
        targetPage * MediaQuery.of(context).size.height,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.animateToPage(
        targetPage,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
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
    if (_imageUrls.isEmpty) {
      return;
    }

    try {
      final currentChapter = _getCurrentChapter();

      await _progressService.saveProgress(
        manga: widget.manga,
        chapter: currentChapter,  // 使用当前章节
        currentPage: _currentPage,
        totalPages: _imageUrls.length,
      );
    } catch (e) {
      // 保存阅读进度失败
    }
  }

  void _preloadNearbyPages() {
    if (_imageUrls.isEmpty) return;

    int start = (_currentPage - _preloadRange).clamp(0, _imageUrls.length - 1);
    int end = (_currentPage + _preloadRange).clamp(0, _imageUrls.length - 1);

    // 智能预加载：优先预加载靠近当前页面的图片
    List<int> pagesToPreload = [];
    for (int i = start; i <= end; i++) {
      // 跳过过渡页面
      if (_imageUrls[i] == _transitionPageMarker) {
        continue;
      }
      if (!_preloadedPages.contains(i)) {
        pagesToPreload.add(i);
      }
    }

    // 按距离排序，优先预加载靠近当前页面的图片
    pagesToPreload.sort((a, b) =>
      (a - _currentPage).abs().compareTo((b - _currentPage).abs())
    );

    // 渐进式预加载
    for (int i = 0; i < pagesToPreload.length; i++) {
      final pageIndex = pagesToPreload[i];
      _preloadedPages.add(pageIndex);

      // 延迟预加载较远的图片
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted) {
          precacheImage(
            CachedNetworkImageProvider(_imageUrls[pageIndex]),
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

  /// 检查是否需要预加载下一章节
  void _checkNextChapterPreload() {
    if (_imageUrls.isEmpty) return;

    final isNearEnd = _currentPage >= _imageUrls.length - _chapterEndPreloadThreshold;

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
    final nextChapterIndex = _currentChapterIndex + 1;

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
          // 预加载下一章节的前几页
          final preloadCount = math.min(5, apiImageFiles.length);

          for (int i = 0; i < preloadCount; i++) {
            final imageUrl = MangaApiService.getChapterImageUrl(
              widget.manga.id,
              nextChapter.id,
              apiImageFiles[i],
            );

            // 使用延迟预加载避免阻塞
            Future.delayed(Duration(milliseconds: i * 100), () {
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

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_config.autoHideControlsDelay, () {
      if (mounted && _showControls) {
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
      _showControls = false;
    });
    _controlsAnimationController.reverse();
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
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
    if (_showControls) {
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
      _currentScale = 1.0;
      _panOffset = Offset.zero;
      _cumulativePanOffset = Offset.zero;
    });
  }


  void _previousPage() {
    if (_currentPage > 0) {
      HapticFeedbackManager.selectionClick();
      final config = PageAnimationManager().getTapAnimationConfig();
      _pageController.previousPage(
        duration: config.duration,
        curve: config.curve,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _imageUrls.length - 1) {
      HapticFeedbackManager.selectionClick();
      final config = PageAnimationManager().getTapAnimationConfig();
      _pageController.nextPage(
        duration: config.duration,
        curve: config.curve,
      );
    } else {
      // 已经在过渡页面（章节末尾），不需要做任何事情
      // 过渡页面已经提供了前往下一章或返回的选项
      HapticFeedbackManager.lightImpact();
    }
  }

  /// 滑动翻页
  void _swipePage(bool isForward, Offset velocity) {
    if (isForward) {
      if (_currentPage < _imageUrls.length - 1) {
        final config = PageAnimationManager().getSwipeAnimationConfig(velocity, true);
        _pageController.nextPage(
          duration: config.duration,
          curve: config.curve,
        );
      }
    } else {
      if (_currentPage > 0) {
        final config = PageAnimationManager().getSwipeAnimationConfig(velocity, false);
        _pageController.previousPage(
          duration: config.duration,
          curve: config.curve,
        );
      }
    }
  }


  /// 显示章节过渡画面
  Future<void> _showChapterTransition() async {
    final nextChapterIndex = _currentChapterIndex + 1;

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
        backgroundColor: Colors.black.withAlpha(230),
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
                  color: Colors.white.withAlpha(204),
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
                    style: TextStyle(color: Colors.white.withAlpha(179)),
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
    if (_isLoadingNextChapter) {
      return;
    }

    setState(() {
      _isLoadingNextChapter = true;
    });

    try {
      final nextChapter = widget.chapters[nextChapterIndex];

      // 加载新章节图片
      final apiImageFiles = await MangaApiService.getChapterImageFiles(
        widget.manga.id,
        nextChapter.id,
      );

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

        // 在章节末尾添加过渡页面
        newImageUrls.add(_transitionPageMarker);

        setState(() {
          _currentChapterIndex = nextChapterIndex;
          _currentPage = 0;
          _imageUrls = newImageUrls;
          _isLoadingNextChapter = false;
        });

        // 重置页面控制器
        _pageController.jumpToPage(0);

        // 立即预加载新章节的图片
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preloadedPages.clear(); // 清空之前的预加载记录
          _preloadNearbyPages();   // 预加载新章节的图片
        });

        // 保存新章节的阅读进度
        _saveReadingProgress();

        _showSnackBar('已切换到第${nextChapter.number}章: ${nextChapter.title}');
      } else {
        setState(() {
          _isLoadingNextChapter = false;
        });
        _showSnackBar('无法获取下一章图片列表');
      }
    } catch (e) {
      setState(() {
        _isLoadingNextChapter = false;
      });
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

  @override
  void dispose() {
    // 移除WidgetsBinding观察者
    WidgetsBinding.instance.removeObserver(this);

    // 退出时保存最终进度
    _saveReadingProgress();

    // 禁用音量键拦截
    _enableVolumeKeyInterception(false);

    // 清理手势处理器
    _gestureHandler?.dispose();

    _pageController.dispose();
    _scrollController.dispose();
    _hideTimer?.cancel();
    _progressSaveTimer?.cancel();
    _nextChapterPreloadTimer?.cancel(); // 清理下一章节预加载定时器
    _settingsAnimationController.dispose();
    _controlsAnimationController.dispose();
    _focusNode.dispose(); // 清理焦点节点

    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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

    if (_errorMessage != null) {
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
                _errorMessage!,
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
                _currentScale = scale;
              });
            },
            onPanChanged: (offset) {
              setState(() {
                // 如果接收到的是 Offset.zero，表示缩放结束，重置累积偏移量
                if (offset == Offset.zero) {
                  _cumulativePanOffset = Offset.zero;
                } else {
                  // 累积平移偏移量，实现平滑拖动
                  _cumulativePanOffset += offset;
                }
                _panOffset = _cumulativePanOffset;
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
                _buildReaderContent(),


                // 顶部控制栏
                if (_showControls)
                  _buildTopControls(),

                // 底部控制栏
                if (_showControls)
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

  Widget _buildReaderContent() {
    if (_readingDirection == ReadingDirection.vertical ||
        _readingDirection == ReadingDirection.webtoon) {
      return _buildVerticalReader();
    } else {
      return _buildHorizontalReader();
    }
  }

  Widget _buildHorizontalReader() {
    final actualLayout = _getActualLayout(context);

    if (actualLayout == PageLayout.single) {
      // 单页模式：使用原始页面列表
      return PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          // 页面切换时重置缩放状态
          _resetZoom();
          setState(() {
            _currentPage = index;
            _readingProgress = index / (_imageUrls.length - 1);
          });
          _preloadNearbyPages();
          // 页面切换时立即保存进度
          _saveReadingProgress();
          if (_showControls) {
            _startHideTimer();
          }

          // 检测是否到达章节末尾（通过滑动翻页时）
          // 注意：_imageUrls.length - 1 是过渡页面
          // 当用户滑动到过渡页面时，标记章节为已阅读
          if (index == _imageUrls.length - 1) {
            // 到达章节末尾，自动标记为已阅读
            _markCurrentChapterAsRead();
            // 不需要显示过渡对话框，因为过渡页面已经提供了选项
          }
        },
        itemCount: _imageUrls.length,
        reverse: _readingDirection == ReadingDirection.rightToLeft,
        itemBuilder: (context, index) {
          return _buildImagePage(_imageUrls[index]);
        },
      );
    } else {
      // 双页模式：使用分组页面
      _pageGroups = _getPageGroups(context);

      return PageView.builder(
        controller: _pageController,
        onPageChanged: (groupIndex) {
          // 页面切换时重置缩放状态
          _resetZoom();

          // 计算对应的原始页面索引
          final group = _pageGroups[groupIndex];
          int newPageIndex = _currentPage;
          if (group.urls.isNotEmpty && group.urls[0] != null) {
            // 使用分组中的第一个非空页面作为当前页面索引
            final firstUrl = group.urls[0]!;
            newPageIndex = _imageUrls.indexOf(firstUrl);
          } else if (group.urls.length > 1 && group.urls[1] != null) {
            final secondUrl = group.urls[1]!;
            newPageIndex = _imageUrls.indexOf(secondUrl);
          }

          // 计算分组内页面索引
          int pageInGroup = 0;
          if (group.urls.isNotEmpty && group.urls[0] != null &&
              _imageUrls.indexOf(group.urls[0]!) == newPageIndex) {
            pageInGroup = 0;
          } else if (group.urls.length > 1 && group.urls[1] != null &&
                     _imageUrls.indexOf(group.urls[1]!) == newPageIndex) {
            pageInGroup = 1;
          }

          setState(() {
            _currentGroupIndex = groupIndex;
            _currentPage = newPageIndex;
            _readingProgress = newPageIndex / (_imageUrls.length - 1);
          });

          _preloadNearbyPages();
          // 页面切换时立即保存进度
          _saveReadingProgress();
          if (_showControls) {
            _startHideTimer();
          }

          // 检测是否到达章节末尾（双页模式下）
          // 注意：_imageUrls.length - 1 是过渡页面
          // 当用户滑动到过渡页面时，标记章节为已阅读
          if (newPageIndex == _imageUrls.length - 1) {
            // 到达章节末尾，自动标记为已阅读
            _markCurrentChapterAsRead();
            // 不需要显示过渡对话框，因为过渡页面已经提供了选项
          }
        },
        itemCount: _pageGroups.length,
        reverse: _readingDirection == ReadingDirection.rightToLeft,
        itemBuilder: (context, groupIndex) {
          final group = _pageGroups[groupIndex];
          return _buildDoublePage(group);
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
          final currentPage = (notification.metrics.pixels / screenHeight).floor().clamp(0, _imageUrls.length - 1);

          if (_currentPage != currentPage) {
            // 页面切换时重置缩放状态
            _resetZoom();
            setState(() {
              _currentPage = currentPage;
              _readingProgress = currentPage / (_imageUrls.length - 1);
            });
            // 滚动页面切换时保存进度
            _saveReadingProgress();

            // 检测是否到达章节末尾（垂直滚动模式）
            // 注意：_imageUrls.length - 1 是过渡页面
            // 当用户滚动到过渡页面时，标记章节为已阅读
            if (currentPage == _imageUrls.length - 1) {
              // 到达章节末尾，自动标记为已阅读
              _markCurrentChapterAsRead();
              // 不需要显示过渡对话框，因为过渡页面已经提供了选项
            }
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.vertical,
        itemCount: _imageUrls.length,
        itemBuilder: (context, index) {
          return _buildImagePage(_imageUrls[index]);
        },
      ),
    );
  }

  Widget _buildImagePage(String imageUrl) {
    if (imageUrl == _transitionPageMarker) {
      return _buildTransitionPage();
    }
    return Container(
      color: Colors.black,
      child: _buildImageContent(imageUrl),
    );
  }

  /// 构建图片核心内容（不带外层Container）
  /// [alignment] 可选的对齐方式，用于双页模式确保图片贴紧分隔线
  Widget _buildImageContent(String imageUrl, {AlignmentGeometry? alignment}) {
    if (imageUrl == _transitionPageMarker) {
      return _buildTransitionPage();
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.scaleDown,
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
    );

    // 如果需要对齐，用Align包裹
    if (alignment != null) {
      imageWidget = Align(
        alignment: alignment,
        child: imageWidget,
      );
    }

    return Transform.scale(
      scale: _currentScale,
      child: Transform.translate(
        offset: _panOffset,
        child: imageWidget,
      ),
    );
  }

  /// 构建双页布局
  Widget _buildDoublePage(PageGroup group) {
    // 检查是否是过渡页面分组
    if (group.urls.isNotEmpty && group.urls[0] == _transitionPageMarker) {
      // 过渡页面独占整个屏幕宽度
      return _buildTransitionPage();
    }

    final isRTL = _readingDirection == ReadingDirection.rightToLeft;

    // 根据阅读方向决定左右页面显示顺序
    // 从左到右阅读：左侧显示第0页，右侧显示第1页
    // 从右到左阅读：左侧显示第1页，右侧显示第0页（先读右侧页面）
    final leftPageIndex = isRTL ? 1 : 0;
    final rightPageIndex = isRTL ? 0 : 1;

    return Container(
      color: Colors.black,
      child: Row(
        children: [
          // 左侧页面 - 右对齐确保贴紧分隔线
          Expanded(
            child: _buildPageInGroup(group, leftPageIndex, isRTL, alignment: Alignment.centerRight),
          ),
          // 1.51像素分隔线
          Container(width: 1.51, color: Colors.black),
          // 右侧页面 - 左对齐确保贴紧分隔线
          Expanded(
            child: _buildPageInGroup(group, rightPageIndex, isRTL, alignment: Alignment.centerLeft),
          ),
        ],
      ),
    );
  }

  /// 构建分组中的单个页面
  /// [alignment] 可选的对齐方式，用于确保图片贴紧分隔线
  Widget _buildPageInGroup(PageGroup group, int index, bool isRTL, {AlignmentGeometry? alignment}) {
    if (index >= group.urls.length || group.urls[index] == null) {
      // 空白页
      return Container(color: Colors.black);
    }

    final url = group.urls[index]!;
    return _buildImageContent(url, alignment: alignment);
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
                  Colors.black.withAlpha(204),
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
                          color: Colors.white.withAlpha(204),
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
                  Colors.black.withAlpha(204),
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
                    overlayColor: const Color(0xFFFF6B6B).withAlpha(51),
                    trackHeight: 4.0,
                  ),
                  child: Slider(
                    value: _currentPage.toDouble(),
                    min: 0,
                    max: (_imageUrls.length - 1).toDouble(),
                    onChanged: (value) {
                      int newPage = value.round();
                      setState(() {
                        _currentPage = newPage;
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
                      '第 ${_currentPage + 1}/${_imageUrls.length} 页',
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
              color: Colors.black.withAlpha(242),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: SingleChildScrollView(
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
                SizedBox(height: 24),
                Text(
                  '双页阅读',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10),
                Column(
                  children: [
                    _buildPageLayoutOption('单页模式', PageLayout.single),
                    SizedBox(height: 8),
                    _buildPageLayoutOption('双页模式', PageLayout.double),
                    SizedBox(height: 8),
                    _buildPageLayoutOption('自动模式', PageLayout.auto),
                    SizedBox(height: 12),
                    _buildToggleOption(
                      '启用页面移位',
                      _dualPageConfig.shiftDoublePage,
                      (value) {
                        setState(() {
                          _dualPageConfig.shiftDoublePage = value;
                        });
                      },
                    ),
                  ],
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

  /// 构建阅读方向选项
  Widget _buildReadingDirectionOption(String title, ReadingDirection direction) {
    final isSelected = _readingDirection == direction;

    return GestureDetector(
      onTap: () {
        setState(() {
          _readingDirection = direction;
          _config = ReadingGestureConfig(
            readingDirection: direction,
            tapToZoom: _config.tapToZoom,
            volumeButtonNavigation: _config.volumeButtonNavigation,
            fullscreenOnTap: _config.fullscreenOnTap,
            keepScreenOn: _config.keepScreenOn,
            autoHideControlsDelay: _config.autoHideControlsDelay,
            enableImmersiveMode: _config.enableImmersiveMode,
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
          color: isSelected ? const Color(0xFFFF6B6B).withAlpha(51) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Color(0xFFFF6B6B) : Colors.grey[700]!,
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

  /// 构建页面布局选项
  Widget _buildPageLayoutOption(String title, PageLayout layout) {
    final isSelected = _dualPageConfig.pageLayout == layout;

    return GestureDetector(
      onTap: () {
        setState(() {
          _dualPageConfig.pageLayout = layout;
        });
        HapticFeedbackManager.lightImpact();
        _showSnackBar('已切换到$title');
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B6B).withAlpha(51) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Color(0xFFFF6B6B) : Colors.grey[700]!,
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

  /// 构建开关选项
  Widget _buildToggleOption(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFFF6B6B),
            trackColor: MaterialStateProperty.all(const Color(0xFFFF6B6B).withAlpha(128)), // ignore: deprecated_member_use
          ),
        ],
      ),
    );
  }

  /// 获取当前的分组页面列表
  List<PageGroup> _getPageGroups(BuildContext context) {
    final isLandscape = DualPageUtils.isLandscape(context);

    // 检查是否有过渡页面
    bool hasTransitionPage = _imageUrls.isNotEmpty && _imageUrls.last == _transitionPageMarker;

    List<String> pagesForGrouping;
    if (hasTransitionPage) {
      // 排除过渡页面进行分组
      pagesForGrouping = _imageUrls.sublist(0, _imageUrls.length - 1);
    } else {
      pagesForGrouping = List.from(_imageUrls);
    }

    // 获取普通页面的分组
    List<PageGroup> groups = DualPageUtils.groupPages(pagesForGrouping, _dualPageConfig, isLandscape);

    // 如果有过渡页面，添加一个特殊分组
    if (hasTransitionPage) {
      // 过渡页面独占一个分组，占据整个屏幕宽度
      groups.add(PageGroup(
        index: groups.length,
        urls: [_transitionPageMarker],
      ));
    }

    return groups;
  }

  /// 获取实际布局（考虑自动模式）
  PageLayout _getActualLayout(BuildContext context) {
    final isLandscape = DualPageUtils.isLandscape(context);
    if (_dualPageConfig.pageLayout == PageLayout.auto) {
      return isLandscape ? PageLayout.double : PageLayout.single;
    }
    return _dualPageConfig.pageLayout;
  }


  /// 构建过渡页面
  Widget _buildTransitionPage() {
    final bool isLastChapter = _currentChapterIndex >= widget.chapters.length - 1;
    final bool hasNextChapter = _currentChapterIndex < widget.chapters.length - 1;
    final Chapter? nextChapter = hasNextChapter ? widget.chapters[_currentChapterIndex + 1] : null;

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLastChapter ? Icons.check_circle : Icons.arrow_forward,
              color: Color(0xFFFF6B6B),
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              isLastChapter ? '已是最后一章' : '章节结束',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (nextChapter != null)
              Text(
                '下一章: 第${nextChapter.number}章 ${nextChapter.title}',
                style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            if (nextChapter != null)
              FutureBuilder<int>(
                future: _getChapterPageCount(nextChapter),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      '共${snapshot.data}页',
                      style: TextStyle(
                        color: Colors.white.withAlpha(179),
                        fontSize: 14,
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
            const SizedBox(height: 32),
            if (hasNextChapter)
              ElevatedButton(
                onPressed: _loadNextChapterAfterTransition,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('前往下一章'),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (isLastChapter) {
                  Navigator.of(context).pop();
                } else {
                  _goBackToPreviousPage();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isLastChapter ? '退出观看' : '返回上一页'),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取章节页数
  Future<int> _getChapterPageCount(Chapter chapter) async {
    try {
      final apiImageFiles = await MangaApiService.getChapterImageFiles(
        widget.manga.id,
        chapter.id,
      );
      return apiImageFiles.length;
    } catch (e) {
      return 0;
    }
  }

  /// 过渡页面中的"前往下一章"按钮点击处理
  void _loadNextChapterAfterTransition() {
    final nextChapterIndex = _currentChapterIndex + 1;
    if (nextChapterIndex < widget.chapters.length) {
      _loadNextChapter(nextChapterIndex);
    }
  }

  /// 返回到前一页漫画
  void _goBackToPreviousPage() {
    if (_currentPage > 0) {
      // 计算目标页面（过渡页面的前一页）
      final targetPage = _currentPage - 1;

      if (_readingDirection == ReadingDirection.vertical ||
          _readingDirection == ReadingDirection.webtoon) {
        _scrollController.animateTo(
          targetPage * MediaQuery.of(context).size.height,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.animateToPage(
          targetPage,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

}
