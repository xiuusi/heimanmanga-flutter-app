import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/manga.dart';
import '../../services/api_service.dart';
import '../../services/reading_progress_service.dart';
import '../../utils/reader_gestures.dart';
import '../../utils/page_animation_manager.dart';
import '../../utils/dual_page_utils.dart';
import '../../utils/page_transform_state.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

class ReaderController extends ChangeNotifier {
  static const String transitionPageMarker = 'transition://chapter_end';

  final Manga manga;
  final Chapter chapter;
  final List<Chapter> chapters;
  final ReadingGestureConfig? initialConfig;

  PageController pageController = PageController();
  ScrollController scrollController = ScrollController();
  AnimationController? settingsAnimationController;
  AnimationController? controlsAnimationController;
  FocusNode focusNode = FocusNode();

  int currentPage = 0;
  bool showControls = true;
  bool isLoading = true;
  String? errorMessage;
  List<String> imageUrls = [];

  /// 真实页数。imageUrls 末尾会追加一个用于"章节结尾过渡"的占位标记，
  /// 它不是章节内容，因此所有"总页数 / 百分比 / 计数"口径都必须用本 getter（P1-6）。
  int get realPageCount {
    if (imageUrls.isEmpty) return 0;
    return imageUrls.last == transitionPageMarker
        ? imageUrls.length - 1
        : imageUrls.length;
  }

  /// 最近一次成功落库的进度，用于避免定时器重复写同一条记录（P1-5）。
  String? _lastSavedChapterId;
  int? _lastSavedPage;

  /// 图片列表代次号：每次换章 / 重新加载都会自增，
  /// 用于丢弃基于旧列表的延迟回调（P2-2）。
  int _imageGeneration = 0;

  DualPageConfig dualPageConfig = DualPageConfig();
  List<PageGroup> pageGroups = [];
  int currentGroupIndex = 0;

  int currentChapterIndex = 0;
  bool isLoadingNextChapter = false;

  Timer? hideTimer;

  final PageTransformManager pageTransformManager = PageTransformManager();

  late ReadingGestureConfig config;
  ReadingDirection readingDirection = ReadingDirection.rightToLeft;

  Set<int> preloadedPages = <int>{};
  static const int preloadRange = 5;
  static const int chapterEndPreloadThreshold = 3;
  bool isNearChapterEnd = false;
  Timer? nextChapterPreloadTimer;

  Timer? progressSaveTimer;

  final ReadingProgressService progressService = ReadingProgressService();
  ReadingProgress? existingProgress;
  bool hasShownJumpPrompt = false;

  bool volumeButtonNavigationEnabled = false;
  bool isChannelListenerSetup = false;

  bool isLastChapterDialogShown = false;

  dynamic gestureHandler;

  ReaderController({
    required this.manga,
    required this.chapter,
    required this.chapters,
    this.initialConfig,
  }) {
    config = initialConfig ?? const ReadingGestureConfig();
    readingDirection = config.readingDirection;
    volumeButtonNavigationEnabled = config.volumeButtonNavigation;

    currentChapterIndex = chapters.indexWhere((c) => c.id == chapter.id);
    if (currentChapterIndex == -1) {
      currentChapterIndex = 0;
    }
  }

  void init(BuildContext context) {
    setSystemUI();
    setupVolumeKeyListener();
    applyVolumeKeyInterception();
    _loadPreferences();
    loadChapterImages(context);
    startHideTimer();
    startProgressSaveTimer();
    loadReadingProgress(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dirIndex = prefs.getInt('reader_reading_direction');
      if (dirIndex != null && dirIndex < ReadingDirection.values.length) {
        readingDirection = ReadingDirection.values[dirIndex];
        config = ReadingGestureConfig(
          readingDirection: readingDirection,
          tapToZoom: config.tapToZoom,
          volumeButtonNavigation: config.volumeButtonNavigation,
          fullscreenOnTap: config.fullscreenOnTap,
          keepScreenOn: config.keepScreenOn,
          autoHideControlsDelay: config.autoHideControlsDelay,
          enableImmersiveMode: config.enableImmersiveMode,
          gestureActions: config.gestureActions,
        );
      }
      final layoutIndex = prefs.getInt('reader_page_layout');
      if (layoutIndex != null && layoutIndex < PageLayout.values.length) {
        dualPageConfig.pageLayout = PageLayout.values[layoutIndex];
      }
      final shift = prefs.getBool('reader_shift_double_page');
      if (shift != null) {
        dualPageConfig.shiftDoublePage = shift;
      }
      final volNav = prefs.getBool('reader_volume_button_nav');
      if (volNav != null) {
        volumeButtonNavigationEnabled = volNav;
      }
      // P1-4：偏好是异步读出来的，读完必须按真实值重新同步原生拦截状态，
      // 否则 init() 阶段用的只是配置默认值（true），用户"关闭"的设置会被忽略。
      setupVolumeKeyListener();
      applyVolumeKeyInterception();
    } catch (e) {
      debugPrint('警告: 加载阅读偏好失败 - $e');
    }
  }

  Chapter getCurrentChapter() {
    if (currentChapterIndex >= 0 && currentChapterIndex < chapters.length) {
      return chapters[currentChapterIndex];
    }
    return chapter;
  }

  void setSystemUI() {
    if (config.keepScreenOn) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void loadChapterImages(BuildContext context) async {
    // P1-2：重试前必须清掉上一次的错误，否则 _EnhancedReaderPageState.build
    // 里的 `if (errorMessage != null)` 会让错误页永久驻留，重试成功后也无法恢复。
    if (errorMessage != null || !isLoading) {
      errorMessage = null;
      isLoading = true;
      notifyListeners();
    }

    try {
      final apiImageFiles = await MangaApiService.getChapterImageFiles(
        manga.id,
        chapter.id,
      );
      if (_disposed) return;

      if (apiImageFiles.isNotEmpty) {
        List<String> urls = [];
        for (String fileName in apiImageFiles) {
          urls.add(
            MangaApiService.getChapterImageUrl(manga.id, chapter.id, fileName),
          );
        }
        urls.add(transitionPageMarker);

        imageUrls = urls;
        errorMessage = null;
        isLoading = false;
        // 新的图片列表意味着旧的页面布局与在途预加载回调全部失效（P1-1 / P2-2）。
        _imageGeneration++;
        clearVerticalPageLayout();
        pageGroups = [];
        _pageGroupsSignature = null;
        notifyListeners();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_disposed) return;
          refreshPageGroups(context);
          preloadNearbyPages(context);
          notifyListeners();
        });
      } else {
        errorMessage = "无法获取章节图片列表";
        isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      if (_disposed) return;
      errorMessage = "加载章节失败: $e";
      isLoading = false;
      notifyListeners();
    }
  }

  void loadReadingProgress(BuildContext context) async {
    try {
      await progressService.init();
      existingProgress = await progressService.getProgress(manga.id, chapterId: chapter.id);

      if (existingProgress != null) {
        if (existingProgress!.shouldPromptJump(chapter.id)) {
          // 进度读取是异步的，期间页面可能已经退出。
          if (_disposed || !context.mounted) return;
          _showJumpToProgressPrompt(context);
        }
      }
    } catch (e) {
      debugPrint('警告: 加载阅读进度失败 - $e');
    }
  }

  void _showJumpToProgressPrompt(BuildContext context) {
    if (hasShownJumpPrompt || existingProgress == null) return;

    final page = existingProgress!.currentPage + 1;
    final total = existingProgress!.totalPages;
    final percentage = (existingProgress!.readingPercentage * 100).toStringAsFixed(1);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('检测到阅读进度'),
        content: Text('上次阅读到第 $page/$total 页 ($percentage%)\n是否跳转到上次阅读位置？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              hasShownJumpPrompt = true;
            },
            child: const Text('从头阅读'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              jumpToProgress(context);
              hasShownJumpPrompt = true;
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary,
            ),
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }

  void jumpToProgress(BuildContext context) {
    if (existingProgress == null) return;

    if (imageUrls.isEmpty) {
      showSnackBar(context, '正在加载图片，请稍后...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _waitForImagesAndJump(context);
      });
      return;
    }

    _performJumpToProgress(context);
  }

  void _waitForImagesAndJump(BuildContext context) async {
    const maxWaitTime = Duration(seconds: 5);
    final startTime = DateTime.now();

    while (imageUrls.isEmpty && DateTime.now().difference(startTime) < maxWaitTime) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (_disposed || !context.mounted) return;
    if (imageUrls.isNotEmpty) {
      _performJumpToProgress(context);
    } else {
      showSnackBar(context, '图片加载超时，请重试');
    }
  }

  void _performJumpToProgress(BuildContext context) {
    if (existingProgress == null || imageUrls.isEmpty) return;

    final targetPage = existingProgress!.currentPage.clamp(0, realPageCount - 1);
    currentPage = targetPage;
    notifyListeners();

    _jumpToPageWhenReady(context, targetPage);

    HapticFeedbackManager.mediumImpact();
  }

  /// 跳转到指定页。
  /// PageView 可能在图片刚加载完、首帧尚未渲染时还没有挂载，
  /// 此时必须延迟到下一帧再执行，否则 PageController 会抛 StateError。
  void _jumpToPageWhenReady(BuildContext context, int pageIndex) {
    if (_disposed) return;

    if (isVerticalMode) {
      goToVerticalPage(pageIndex, duration: const Duration(milliseconds: 500));
      return;
    }

    final targetIndex = _getGroupIndexForPage(context, pageIndex);
    if (pageController.hasClients) {
      pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !pageController.hasClients) return;
      pageController.jumpToPage(targetIndex);
    });
  }

  Future<void> markCurrentChapterAsRead() async {
    try {
      final ch = getCurrentChapter();
      await progressService.markChapterAsRead(
        mangaId: manga.id,
        chapterId: ch.id,
        isRead: true,
      );
    } catch (e) {
      debugPrint('警告: 标记章节已读失败 - $e');
    }
  }

  Future<void> saveReadingProgress() async {
    if (imageUrls.isEmpty) return;

    final total = realPageCount;
    if (total <= 0) return;

    final ch = getCurrentChapter();
    // 过渡页不是真实页面，落库时把页码夹回最后一页（P1-6）。
    final page = currentPage.clamp(0, total - 1);

    // 页码/章节没有变化时不必重复写库（P1-5：原先每 5 秒无条件写一次）。
    if (_lastSavedChapterId == ch.id && _lastSavedPage == page) return;

    try {
      await progressService.saveProgress(
        manga: manga,
        chapter: ch,
        currentPage: page,
        totalPages: total,
      );
      _lastSavedChapterId = ch.id;
      _lastSavedPage = page;
    } catch (e) {
      debugPrint('警告: 保存阅读进度失败 - $e');
    }
  }

  void preloadNearbyPages(BuildContext context) {
    if (imageUrls.isEmpty) return;

    final start = (currentPage - preloadRange).clamp(0, imageUrls.length - 1);
    final end = (currentPage + preloadRange).clamp(0, imageUrls.length - 1);

    final pagesToPreload = <int>[];
    for (int i = start; i <= end; i++) {
      if (imageUrls[i] == transitionPageMarker) continue;
      if (!preloadedPages.contains(i)) {
        pagesToPreload.add(i);
      }
    }

    pagesToPreload.sort((a, b) =>
      (a - currentPage).abs().compareTo((b - currentPage).abs())
    );

    // P2-2：延迟回调里不能再读 imageUrls（切章后它已被替换成更短的列表，
    // 旧下标会抛 RangeError），也不能对已卸载的元素调 precacheImage。
    // 因此捕获 URL 字符串，并用代次号判断图片列表是否已经换过。
    final generation = _imageGeneration;
    for (int i = 0; i < pagesToPreload.length; i++) {
      final pageIndex = pagesToPreload[i];
      final imageUrl = imageUrls[pageIndex];
      preloadedPages.add(pageIndex);

      Future.delayed(Duration(milliseconds: i * 50), () {
        if (_disposed || !context.mounted || generation != _imageGeneration) return;
        precacheImage(
          CachedNetworkImageProvider(imageUrl),
          context,
          onError: (_, __) => preloadedPages.remove(pageIndex),
        );
      });
    }

    _checkNextChapterPreload(context);
  }

  void _checkNextChapterPreload(BuildContext context) {
    if (imageUrls.isEmpty) return;

    final isNearEnd = currentPage >= imageUrls.length - chapterEndPreloadThreshold;

    if (isNearEnd && !isNearChapterEnd) {
      isNearChapterEnd = true;
      _preloadNextChapter(context);
    } else if (!isNearEnd && isNearChapterEnd) {
      isNearChapterEnd = false;
      cancelNextChapterPreload();
    }
  }

  Future<void> _preloadNextChapter(BuildContext context) async {
    final nextIdx = currentChapterIndex + 1;
    if (nextIdx >= chapters.length) return;

    nextChapterPreloadTimer?.cancel();

    nextChapterPreloadTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final nextChapter = chapters[nextIdx];
        final apiImageFiles = await MangaApiService.getChapterImageFiles(
          manga.id,
          nextChapter.id,
        );

        if (apiImageFiles.isNotEmpty) {
          final count = math.min(5, apiImageFiles.length);
          for (int i = 0; i < count; i++) {
            final imageUrl = MangaApiService.getChapterImageUrl(
              manga.id, nextChapter.id, apiImageFiles[i],
            );
            Future.delayed(Duration(milliseconds: i * 100), () {
              if (_disposed || !context.mounted) return;
              precacheImage(CachedNetworkImageProvider(imageUrl), context);
            });
          }
        }
      } catch (e) {
        debugPrint('警告: 预加载下一章失败 - $e');
      }
    });
  }

  void cancelNextChapterPreload() {
    nextChapterPreloadTimer?.cancel();
    nextChapterPreloadTimer = null;
  }

  void refreshPreload(BuildContext context) {
    preloadedPages.clear();
    preloadNearbyPages(context);
  }

  void startHideTimer() {
    hideTimer?.cancel();
    hideTimer = Timer(config.autoHideControlsDelay, () {
      if (showControls) {
        hideControls();
      }
    });
  }

  void startProgressSaveTimer() {
    progressSaveTimer?.cancel();
    progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      saveReadingProgress();
    });
  }

  void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void hideControls() {
    showControls = false;
    notifyListeners();
    controlsAnimationController?.reverse();
  }

  void showControlsTemporarily() {
    showControls = true;
    notifyListeners();
    controlsAnimationController?.forward();
    startHideTimer();
  }

  void handleAction(String action, BuildContext context) {
    if (_isCurrentPageZoomed(context)) {
      if (action == 'toggle_ui' || action == 'previous_page' || action == 'next_page') {
        HapticFeedbackManager.lightImpact();
        resetZoom();
        return;
      }
    }

    switch (action) {
      case 'previous_page':
        previousPage();
        break;
      case 'next_page':
        nextPage();
        break;
      case 'toggle_ui':
        toggleUI();
        break;
      case 'menu':
      case 'settings':
        showSettings();
        break;
    }
  }

  bool _isCurrentPageZoomed(BuildContext context) {
    final actualLayout = _getActualLayout(context);
    final stateKey = actualLayout == PageLayout.double
        ? 'group_$currentGroupIndex'
        : 'page_$currentPage';
    return pageTransformManager.getState(stateKey).isZoomed;
  }

  void toggleUI() {
    HapticFeedbackManager.lightImpact();
    if (showControls) {
      hideControls();
    } else {
      showControlsTemporarily();
    }
  }

  void resetZoom() {
    pageTransformManager.resetAll();
  }

  void handlePageZoomChanged(String stateKey, double scale) {
    pageTransformManager.updateScale(stateKey, scale);
  }

  void handlePagePanChanged(String stateKey, Offset offset, AlignmentGeometry? alignment, BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    pageTransformManager.updatePanOffset(stateKey, offset, alignment: alignment, viewportSize: screenSize);
  }

  /// 竖屏滚动 / 网漫模式只构建 ListView，不会挂载 PageView，
  /// 此时 pageController 没有任何 position，直接调用翻页会抛 StateError。
  bool get isVerticalMode =>
      readingDirection == ReadingDirection.vertical ||
      readingDirection == ReadingDirection.webtoon;

  /// 控制器是否已释放，用于丢弃延迟到下一帧的回调。
  bool _disposed = false;

  void previousPage() {
    if (currentPage > 0) {
      HapticFeedbackManager.selectionClick();
      final animConfig = PageAnimationManager().getTapAnimationConfig();
      _turnPage(-1, animConfig.duration, animConfig.curve);
    }
  }

  void nextPage() {
    if (currentPage < imageUrls.length - 1) {
      HapticFeedbackManager.selectionClick();
      final animConfig = PageAnimationManager().getTapAnimationConfig();
      _turnPage(1, animConfig.duration, animConfig.curve);
    } else {
      HapticFeedbackManager.lightImpact();
    }
  }

  void swipePage(bool isForward, Offset velocity) {
    if (isForward) {
      if (currentPage < imageUrls.length - 1) {
        final animConfig = PageAnimationManager().getSwipeAnimationConfig(velocity, true);
        _turnPage(1, animConfig.duration, animConfig.curve);
      }
    } else {
      if (currentPage > 0) {
        final animConfig = PageAnimationManager().getSwipeAnimationConfig(velocity, false);
        _turnPage(-1, animConfig.duration, animConfig.curve);
      }
    }
  }

  /// 翻到相邻页（delta 为 +1 / -1）。
  /// 竖屏/网漫模式走 scrollController，横向模式走 PageView。
  /// 两个 controller 都必须先判断 hasClients，否则在未挂载时会抛 StateError。
  void _turnPage(int delta, Duration duration, Curve curve) {
    if (_disposed) return;

    if (isVerticalMode) {
      if (!scrollController.hasClients) return;
      goToVerticalPage(currentPage + delta, duration: duration);
      return;
    }

    if (!pageController.hasClients) return;
    if (delta > 0) {
      pageController.nextPage(duration: duration, curve: curve);
    } else {
      pageController.previousPage(duration: duration, curve: curve);
    }
  }

  // ---------------------------------------------------------------------------
  // 竖屏模式的真实布局信息（P1-1）
  //
  // 竖屏阅读器是连续滚动的 ListView，每一项的高度由图片宽高比决定，并不等于
  // 屏幕高度。原先用 `pixels / screenHeight` 推断页码、用 `page * screenHeight`
  // 定位，两个假设都不成立，导致页码 / 进度 / 跳转整体偏移。
  // 现在由列表项在布局完成后回填真实偏移：页码取"视口顶部所在的页"，
  // 翻页则直接滚动到目标页的真实偏移。
  // ---------------------------------------------------------------------------

  /// 每页顶部在滚动坐标系中的偏移与高度。
  final Map<int, double> _pageTops = {};
  final Map<int, double> _pageHeights = {};

  /// 列表项布局完成后回填（见 `_VerticalPageMeasure`）。
  /// 注意：这里不 notifyListeners，避免"回填 → 重建 → 再回填"的循环。
  void reportVerticalPageLayout(int index, double top, double height) {
    if (_disposed) return;
    if (_pageTops[index] == top && _pageHeights[index] == height) return;
    _pageTops[index] = top;
    _pageHeights[index] = height;
  }

  /// 章节 / 阅读方向 / 布局变化后丢弃旧的布局缓存。
  void clearVerticalPageLayout() {
    _pageTops.clear();
    _pageHeights.clear();
  }

  /// 当前页 = 视口顶部所在的页；尚无测量数据时退化为按视口高度估算。
  int resolveVerticalPageIndex() {
    if (!scrollController.hasClients) return currentPage;
    final position = scrollController.position;
    final pixels = position.pixels;

    if (_pageTops.isNotEmpty) {
      int? bestIndex;
      var bestTop = double.negativeInfinity;
      for (final entry in _pageTops.entries) {
        final top = entry.value;
        if (top <= pixels + 1.0 && top > bestTop) {
          bestTop = top;
          bestIndex = entry.key;
        }
      }
      if (bestIndex != null) return bestIndex;
    }

    final viewport = position.viewportDimension;
    if (viewport <= 0 || imageUrls.isEmpty) return currentPage;
    return (pixels / viewport).floor().clamp(0, imageUrls.length - 1);
  }

  /// 第 page 页对应的滚动偏移；无测量数据时退化为按视口高度估算。
  double verticalOffsetForPage(int page) {
    if (!scrollController.hasClients) return 0;
    final max = scrollController.position.maxScrollExtent;
    final measured = _pageTops[page];
    if (measured != null) return measured.clamp(0.0, max);
    final viewport = scrollController.position.viewportDimension;
    return (page * viewport).clamp(0.0, max);
  }

  /// 竖屏模式跳转到指定页（索引含末尾的合成过渡页）。
  void goToVerticalPage(int page, {Duration duration = const Duration(milliseconds: 300)}) {
    if (_disposed) return;
    if (!scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || !scrollController.hasClients) return;
        scrollController.jumpTo(verticalOffsetForPage(page));
      });
      return;
    }
    scrollController.animateTo(
      verticalOffsetForPage(page),
      duration: duration,
      curve: Curves.easeInOut,
    );
  }

  Future<void> showChapterTransition(BuildContext context) async {
    final nextIdx = currentChapterIndex + 1;

    if (nextIdx >= chapters.length) {
      _handleLastChapterReached(context);
      return;
    }

    final nextChapter = chapters[nextIdx];
    _showTransitionDialog(context, '正在前往下一章',
      '第${nextChapter.number}话: ${nextChapter.title}',
      onConfirm: () => loadNextChapter(context, nextIdx),
    );
  }

  void _showTransitionDialog(BuildContext context, String title, String message, {VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
                color: Theme.of(ctx).colorScheme.primary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
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
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(color: Colors.white.withAlpha(179)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('前往下一章'),
                ),
              ]
            : [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('退出观看'),
                ),
              ],
      ),
    );
  }

  Future<void> loadNextChapter(BuildContext context, int nextChapterIndex) async {
    if (isLoadingNextChapter) return;

    isLoadingNextChapter = true;
    notifyListeners();

    try {
      final nextChapter = chapters[nextChapterIndex];
      final apiImageFiles = await MangaApiService.getChapterImageFiles(
        manga.id,
        nextChapter.id,
      );

      // 网络请求期间页面可能已经退出，下面所有分支都会用到 context。
      if (_disposed || !context.mounted) return;

      if (apiImageFiles.isNotEmpty) {
        List<String> newUrls = [];
        for (String fileName in apiImageFiles) {
          newUrls.add(
            MangaApiService.getChapterImageUrl(manga.id, nextChapter.id, fileName),
          );
        }
        newUrls.add(transitionPageMarker);

        currentChapterIndex = nextChapterIndex;
        currentPage = 0;
        imageUrls = newUrls;
        isLoadingNextChapter = false;
        // 换章后页面布局与在途预加载回调失效（P1-1 / P2-2）。
        _imageGeneration++;
        clearVerticalPageLayout();
        pageGroups = [];
        _pageGroupsSignature = null;
        notifyListeners();

        // 竖屏/网漫模式没有 PageView，pageController 未挂载；
        // 直接调用会抛 StateError，并被下方的 catch 误报成"加载下一章失败"。
        if (scrollController.hasClients) {
          scrollController.jumpTo(0);
        }
        if (pageController.hasClients) {
          pageController.jumpToPage(0);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          pageGroups = getPageGroups(context);
          preloadedPages.clear();
          preloadNearbyPages(context);
        });

        saveReadingProgress();
        showSnackBar(context, '已切换到第${nextChapter.number}章: ${nextChapter.title}');
      } else {
        isLoadingNextChapter = false;
        notifyListeners();
        showSnackBar(context, '无法获取下一章图片列表');
      }
    } catch (e) {
      isLoadingNextChapter = false;
      notifyListeners();
      if (!_disposed && context.mounted) {
        showSnackBar(context, '加载下一章失败');
      }
    }
  }

  void setVolumeButtonNavigation(bool enabled) {
    volumeButtonNavigationEnabled = enabled;
    setupVolumeKeyListener();
    applyVolumeKeyInterception();
    _saveBool('reader_volume_button_nav', enabled);
    notifyListeners();
  }

  void setPageLayout(PageLayout layout) {
    dualPageConfig.pageLayout = layout;
    clearVerticalPageLayout();
    _saveInt('reader_page_layout', layout.index);
    notifyListeners();
  }

  void setShiftDoublePage(bool value) {
    dualPageConfig.shiftDoublePage = value;
    _saveBool('reader_shift_double_page', value);
    notifyListeners();
  }

  Future<void> _saveInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (e) {
      debugPrint('警告: 保存阅读偏好失败($key) - $e');
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('警告: 保存阅读偏好失败($key) - $e');
    }
  }

  void showSettings() {
    HapticFeedbackManager.mediumImpact();
    settingsAnimationController?.forward();
  }

  void _handleLastChapterReached(BuildContext context) {
    if (!isLastChapterDialogShown) {
      isLastChapterDialogShown = true;
      _showTransitionDialog(context, '已是最后一章', '您已经阅读完所有章节');
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 注册原生音量键事件回调（整个控制器生命周期内只注册一次）。
  /// 是否真正翻页由 [volumeButtonNavigationEnabled] 在事件回调里判断（P1-4）。
  void setupVolumeKeyListener() {
    if (isChannelListenerSetup) return;

    const MethodChannel('io.xiuusi.heimanmanga/volume_keys')
        .setMethodCallHandler((MethodCall call) async {
      if (call.method != 'onVolumeKeyPressed') return;
      // P1-4：开关关闭时必须在回调内直接忽略，不能只靠"不注册回调"表达关闭。
      if (!volumeButtonNavigationEnabled) return;
      final args = call.arguments;
      final key = args is Map ? args['key'] as String? : null;
      if (key == 'volume_up') {
        previousPage();
      } else if (key == 'volume_down') {
        nextPage();
      }
    });

    isChannelListenerSetup = true;
  }

  /// 把当前开关状态同步给原生层。
  /// P1-4：原先 init() 里硬编码 `enableVolumeKeyInterception(true)`，
  /// 导致用户关闭"音量键翻页"后，系统音量键仍被原生层拦截吞掉（既不能翻页也不能调音量）。
  void applyVolumeKeyInterception() {
    enableVolumeKeyInterception(volumeButtonNavigationEnabled);
  }

  /// 注销原生回调，避免阅读器关闭后控制器仍被 MethodChannel 长期引用。
  void disposeVolumeKeyListener() {
    const MethodChannel('io.xiuusi.heimanmanga/volume_keys')
        .setMethodCallHandler(null);
    isChannelListenerSetup = false;
  }

  Future<void> enableVolumeKeyInterception(bool enabled) async {
    try {
      await const MethodChannel('io.xiuusi.heimanmanga/volume_keys').invokeMethod(
        'setVolumeKeyInterception',
        {'enabled': enabled},
      );
    } catch (e) {
      debugPrint('警告: 音量键拦截失败 - $e');
    }
  }

  void onPageChanged(BuildContext context, int index, bool isGroup) {
    resetZoom();

    if (isGroup) {
      if (index >= pageGroups.length) return;
      final group = pageGroups[index];
      int newPageIndex = currentPage;
      if (group.urls.isNotEmpty && group.urls[0] != null) {
        newPageIndex = imageUrls.indexOf(group.urls[0]!);
      } else if (group.urls.length > 1 && group.urls[1] != null) {
        newPageIndex = imageUrls.indexOf(group.urls[1]!);
      }
      if (newPageIndex == -1) newPageIndex = 0;

      currentGroupIndex = index;
      currentPage = newPageIndex;
    } else {
      currentPage = index;
    }

    notifyListeners();

    preloadNearbyPages(context);
    saveReadingProgress();

    if (showControls) {
      startHideTimer();
    }

    // 读到最后一页"真实内容"即视为已读完，不再要求滑到合成过渡页（P1-6）。
    if (realPageCount > 0 && currentPage >= realPageCount - 1) {
      markCurrentChapterAsRead();
    }
  }

  String getPageStateKey(BuildContext context, int pageIndex, {int? groupIndex, int? pageInGroup}) {
    final actualLayout = _getActualLayout(context);
    if (actualLayout == PageLayout.single) {
      return 'page_$pageIndex';
    } else {
      final gIdx = groupIndex ?? _getGroupIndexForPage(context, pageIndex);
      return 'group_$gIdx';
    }
  }

  int _getGroupIndexForPage(BuildContext context, int pageIndex) {
    if (imageUrls.isEmpty) return 0;
    final clamped = pageIndex.clamp(0, imageUrls.length - 1);
    final actualLayout = _getActualLayout(context);
    if (actualLayout == PageLayout.single) return clamped;
    return DualPageUtils.findGroupIndex(clamped, actualLayout, dualPageConfig.shiftDoublePage);
  }

  List<PageGroup> getPageGroups(BuildContext context) {
    final isLandscape = DualPageUtils.isLandscape(context);
    final hasTransitionPage = imageUrls.isNotEmpty && imageUrls.last == transitionPageMarker;

    List<String> pagesForGrouping;
    if (hasTransitionPage) {
      pagesForGrouping = imageUrls.sublist(0, imageUrls.length - 1);
    } else {
      pagesForGrouping = List.from(imageUrls);
    }

    final groups = DualPageUtils.groupPages(pagesForGrouping, dualPageConfig, isLandscape);

    if (hasTransitionPage) {
      groups.add(PageGroup(
        index: groups.length,
        urls: [transitionPageMarker],
      ));
    }

    return groups;
  }

  /// P2-13：原先页面在 build() 里直接 `pageGroups = getPageGroups(context)`，
  /// 属于"在 build 中修改状态"。改为在帧后按签名刷新缓存，页面只读取缓存。
  String? _pageGroupsSignature;

  void refreshPageGroups(BuildContext context) {
    if (_disposed) return;
    final layout = _getActualLayout(context);
    final signature = '${imageUrls.length}|${layout.name}'
        '|${dualPageConfig.shiftDoublePage}|${DualPageUtils.isLandscape(context)}';
    if (signature == _pageGroupsSignature) return;
    pageGroups = getPageGroups(context);
    _pageGroupsSignature = signature;
  }

  /// P2-12：切换阅读方向 / 布局后，新的 PageView（或 ListView）会从 0 开始，
  /// 而 currentPage 还是切换前的值，导致页码计数与实际显示不一致。
  /// 由页面在新布局完成一帧后调用，把控制器重新定位到 currentPage。
  void syncControllersToCurrentPage(BuildContext context, {int attempt = 0}) {
    if (_disposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final page = currentPage;

      if (isVerticalMode) {
        if (!scrollController.hasClients) return;
        if (_pageTops[page] == null && attempt < 2) {
          // 竖屏布局回填还没完成，再等一帧（最多重试 2 次）。
          syncControllersToCurrentPage(context, attempt: attempt + 1);
          return;
        }
        scrollController.jumpTo(verticalOffsetForPage(page));
        return;
      }

      if (!pageController.hasClients) return;
      pageController.jumpToPage(_getGroupIndexForPage(context, page));
    });
  }

  PageLayout _getActualLayout(BuildContext context) {
    final isLandscape = DualPageUtils.isLandscape(context);
    if (dualPageConfig.pageLayout == PageLayout.auto) {
      return isLandscape ? PageLayout.double : PageLayout.single;
    }
    return dualPageConfig.pageLayout;
  }

  PageLayout getActualLayout(BuildContext context) => _getActualLayout(context);

  void setReadingDirection(ReadingDirection direction) {
    readingDirection = direction;
    // 方向切换会重建阅读区（ListView ↔ PageView），布局缓存必须失效（P1-1）。
    clearVerticalPageLayout();
    config = ReadingGestureConfig(
      readingDirection: direction,
      tapToZoom: config.tapToZoom,
      volumeButtonNavigation: config.volumeButtonNavigation,
      fullscreenOnTap: config.fullscreenOnTap,
      keepScreenOn: config.keepScreenOn,
      autoHideControlsDelay: config.autoHideControlsDelay,
      enableImmersiveMode: config.enableImmersiveMode,
      gestureActions: config.gestureActions,
    );
    _saveInt('reader_reading_direction', direction.index);
    notifyListeners();
  }

  int getGroupIndexForPage(BuildContext context, int pageIndex) {
    return _getGroupIndexForPage(context, pageIndex);
  }

  void notifyExternal() {
    notifyListeners();
  }

  void disposeController() {
    _disposed = true;
    disposeVolumeKeyListener();
    hideTimer?.cancel();
    progressSaveTimer?.cancel();
    nextChapterPreloadTimer?.cancel();
    pageController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    // P2-5：ChangeNotifier 自身与页面变换管理器此前从未被释放。
    // 调用方必须先 removeListener，再调用本方法。
    pageTransformManager.dispose();
    super.dispose();
  }
}
