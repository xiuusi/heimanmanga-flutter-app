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

  DualPageConfig dualPageConfig = DualPageConfig();
  List<PageGroup> pageGroups = [];
  int currentGroupIndex = 0;

  int currentChapterIndex = 0;
  bool isLoadingNextChapter = false;

  Timer? hideTimer;
  bool isInFullscreen = false;

  final PageTransformManager pageTransformManager = PageTransformManager();

  late ReadingGestureConfig config;
  ReadingDirection readingDirection = ReadingDirection.rightToLeft;

  Set<int> preloadedPages = <int>{};
  static const int preloadRange = 5;
  static const int chapterEndPreloadThreshold = 3;
  bool isNearChapterEnd = false;
  Timer? nextChapterPreloadTimer;

  double readingProgress = 0.0;
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
    config = initialConfig ?? ReadingGestureConfig();
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
    enableVolumeKeyInterception(true);
    loadChapterImages(context);
    startHideTimer();
    startProgressSaveTimer();
    loadReadingProgress(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
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
    try {
      final apiImageFiles = await MangaApiService.getChapterImageFiles(
        manga.id,
        chapter.id,
      );

      if (apiImageFiles.isNotEmpty) {
        List<String> urls = [];
        for (String fileName in apiImageFiles) {
          urls.add(
            MangaApiService.getChapterImageUrl(manga.id, chapter.id, fileName),
          );
        }
        urls.add(transitionPageMarker);

        imageUrls = urls;
        isLoading = false;
        notifyListeners();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          pageGroups = _getPageGroups(context);
          preloadNearbyPages(context);
          notifyListeners();
        });
      } else {
        errorMessage = "无法获取章节图片列表";
        isLoading = false;
        notifyListeners();
      }
    } catch (e) {
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
          _showJumpToProgressPrompt(context);
        }
      }
    } catch (e) {
      // ignore
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
              backgroundColor: const Color(0xFFFF6B6B),
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
    final maxWaitTime = const Duration(seconds: 5);
    final startTime = DateTime.now();

    while (imageUrls.isEmpty && DateTime.now().difference(startTime) < maxWaitTime) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (imageUrls.isNotEmpty) {
      _performJumpToProgress(context);
    } else {
      showSnackBar(context, '图片加载超时，请重试');
    }
  }

  void _performJumpToProgress(BuildContext context) {
    if (existingProgress == null || imageUrls.isEmpty) return;

    final targetPage = existingProgress!.currentPage.clamp(0, imageUrls.length - 1);
    currentPage = targetPage;
    notifyListeners();

    if (readingDirection == ReadingDirection.vertical ||
        readingDirection == ReadingDirection.webtoon) {
      scrollController.animateTo(
        targetPage * MediaQuery.of(context).size.height,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      final targetIndex = _getGroupIndexForPage(context, targetPage);
      pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }

    HapticFeedbackManager.mediumImpact();
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
      // ignore
    }
  }

  Future<void> saveReadingProgress() async {
    if (imageUrls.isEmpty) return;

    try {
      final ch = getCurrentChapter();
      await progressService.saveProgress(
        manga: manga,
        chapter: ch,
        currentPage: currentPage,
        totalPages: imageUrls.length,
      );
    } catch (e) {
      // ignore
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

    for (int i = 0; i < pagesToPreload.length; i++) {
      final pageIndex = pagesToPreload[i];
      preloadedPages.add(pageIndex);

      Future.delayed(Duration(milliseconds: i * 50), () {
        precacheImage(
          CachedNetworkImageProvider(imageUrls[pageIndex]),
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
              precacheImage(CachedNetworkImageProvider(imageUrl), context);
            });
          }
        }
      } catch (e) {
        // ignore
      }
    });
  }

  void cancelNextChapterPreload() {
    nextChapterPreloadTimer?.cancel();
    nextChapterPreloadTimer = null;
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
    gestureHandler?.cancelZoomReset();
    pageTransformManager.resetAll();
  }

  void handlePageZoomChanged(String stateKey, double scale) {
    pageTransformManager.updateScale(stateKey, scale);
  }

  void handlePagePanChanged(String stateKey, Offset offset, AlignmentGeometry? alignment, BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    pageTransformManager.updatePanOffset(stateKey, offset, alignment: alignment, viewportSize: screenSize);
  }

  void previousPage() {
    if (currentPage > 0) {
      HapticFeedbackManager.selectionClick();
      final animConfig = PageAnimationManager().getTapAnimationConfig();
      pageController.previousPage(
        duration: animConfig.duration,
        curve: animConfig.curve,
      );
    }
  }

  void nextPage() {
    if (currentPage < imageUrls.length - 1) {
      HapticFeedbackManager.selectionClick();
      final animConfig = PageAnimationManager().getTapAnimationConfig();
      pageController.nextPage(
        duration: animConfig.duration,
        curve: animConfig.curve,
      );
    } else {
      HapticFeedbackManager.lightImpact();
    }
  }

  void swipePage(bool isForward, Offset velocity) {
    if (isForward) {
      if (currentPage < imageUrls.length - 1) {
        final animConfig = PageAnimationManager().getSwipeAnimationConfig(velocity, true);
        pageController.nextPage(
          duration: animConfig.duration,
          curve: animConfig.curve,
        );
      }
    } else {
      if (currentPage > 0) {
        final animConfig = PageAnimationManager().getSwipeAnimationConfig(velocity, false);
        pageController.previousPage(
          duration: animConfig.duration,
          curve: animConfig.curve,
        );
      }
    }
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
                color: const Color(0xFFFF6B6B),
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
                    backgroundColor: const Color(0xFFFF6B6B),
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
                    backgroundColor: const Color(0xFFFF6B6B),
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
        notifyListeners();

        pageController.jumpToPage(0);

        WidgetsBinding.instance.addPostFrameCallback((_) {
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
      showSnackBar(context, '加载下一章失败');
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

  void setupVolumeKeyListener() {
    if (isChannelListenerSetup || !volumeButtonNavigationEnabled) return;

    const MethodChannel('io.xiuusi.heimanmanga/volume_keys')
        .setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onVolumeKeyPressed') {
        final String key = call.arguments['key'];
        if (key == 'volume_up') {
          previousPage();
        } else if (key == 'volume_down') {
          nextPage();
        }
      }
    });

    isChannelListenerSetup = true;
  }

  Future<void> enableVolumeKeyInterception(bool enabled) async {
    try {
      await const MethodChannel('io.xiuusi.heimanmanga/volume_keys').invokeMethod(
        'setVolumeKeyInterception',
        {'enabled': enabled},
      );
    } catch (e) {
      // ignore
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

    readingProgress = imageUrls.isNotEmpty
        ? currentPage / (imageUrls.length - 1)
        : 0.0;
    notifyListeners();

    preloadNearbyPages(context);
    saveReadingProgress();

    if (showControls) {
      startHideTimer();
    }

    if (currentPage == imageUrls.length - 1 && imageUrls.isNotEmpty) {
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

  List<PageGroup> _getPageGroups(BuildContext context) {
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
    notifyListeners();
  }

  int getGroupIndexForPage(BuildContext context, int pageIndex) {
    return _getGroupIndexForPage(context, pageIndex);
  }

  void notifyExternal() {
    notifyListeners();
  }

  void disposeController() {
    hideTimer?.cancel();
    progressSaveTimer?.cancel();
    nextChapterPreloadTimer?.cancel();
    pageController.dispose();
    scrollController.dispose();
    focusNode.dispose();
  }
}
