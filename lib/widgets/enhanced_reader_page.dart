import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import '../models/manga.dart';
import '../utils/reader_gestures.dart';
import '../utils/dual_page_utils.dart';
import 'reader/reader_controller.dart';
import 'reader/reader_settings_panel.dart';
import 'reader/reader_status_widgets.dart';
import 'reader/reader_controls.dart';
import 'reader/reader_page_renderer.dart';

class EnhancedReaderPage extends StatefulWidget {
  static const platform = MethodChannel('io.xiuusi.heimanmanga/volume_keys');
  final Manga manga;
  final Chapter chapter;
  final List<Chapter> chapters;
  final ReadingGestureConfig? initialConfig;

  const EnhancedReaderPage({
    super.key,
    required this.manga,
    required this.chapter,
    required this.chapters,
    this.initialConfig,
  });

  @override
  State<EnhancedReaderPage> createState() => _EnhancedReaderPageState();
}

class _EnhancedReaderPageState extends State<EnhancedReaderPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late ReaderController _controller;
  late AnimationController _settingsAnimationController;
  late AnimationController _controlsAnimationController;

  /// 上一次的阅读方向 / 实际布局，用于在切换后重新同步页码（P2-12）。
  ReadingDirection? _lastDirection;
  PageLayout? _lastLayout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _settingsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    // P2-11：控制栏初始就是显示的（ReaderController.showControls 默认为 true），
    // 动画值必须对齐，否则首帧控制栏会停在屏幕外。
    _controlsAnimationController.value = 1.0;

    _controller = ReaderController(
      manga: widget.manga,
      chapter: widget.chapter,
      chapters: widget.chapters,
      initialConfig: widget.initialConfig,
    );
    _controller.settingsAnimationController = _settingsAnimationController;
    _controller.controlsAnimationController = _controlsAnimationController;
    _controller.addListener(_onControllerChanged);
    _controller.init(context);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 阅读方向 / 布局发生变化时，帧后刷新分页分组并把控制器重新定位到当前页
  /// （P2-12 页码重映射 / P2-13 分组缓存刷新）。
  void _scheduleLayoutSync(PageLayout actualLayout) {
    final direction = _controller.readingDirection;
    final changed =
        _lastDirection != null &&
        (_lastDirection != direction || _lastLayout != actualLayout);
    _lastDirection = direction;
    _lastLayout = actualLayout;
    if (!changed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.refreshPageGroups(context);
      _controller.syncControllersToCurrentPage(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refreshPreload(context);
    }
  }

  @override
  Future<bool> didPopRoute() async {
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.saveReadingProgress();
    _controller.enableVolumeKeyInterception(false);
    _controller.gestureHandler?.dispose();
    // 必须先摘掉监听，再释放 controller（dispose() 之后不能再 removeListener）。
    _controller.removeListener(_onControllerChanged);
    _controller.disposeController();
    _settingsAnimationController.dispose();
    _controlsAnimationController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actualLayout = _controller.getActualLayout(context);
    _scheduleLayoutSync(actualLayout);

    String currentPageStateKey = 'page_${_controller.currentPage}';
    String leftPageStateKey = '';
    String rightPageStateKey = '';
    AlignmentGeometry? leftPageAlignment;
    AlignmentGeometry? rightPageAlignment;

    if (actualLayout == PageLayout.double &&
        _controller.pageGroups.isNotEmpty) {
      final currentGroupIndex = _controller.currentGroupIndex.clamp(
        0,
        _controller.pageGroups.length - 1,
      );
      currentPageStateKey = 'group_$currentGroupIndex';
      leftPageStateKey = currentPageStateKey;
      rightPageStateKey = currentPageStateKey;
      leftPageAlignment = Alignment.centerRight;
      rightPageAlignment = Alignment.centerLeft;
    }

    if (_controller.isLoading) {
      return const ReaderLoadingWidget();
    }

    if (_controller.errorMessage != null) {
      return ReaderErrorWidget(
        errorMessage: _controller.errorMessage!,
        onRetry: () => _controller.loadChapterImages(context),
      );
    }

    final transitionPage = ReaderTransitionPage(
      controller: _controller,
      chapters: widget.chapters,
      mangaId: widget.manga.id,
      onGoBack: _goBackToPreviousPage,
      parentContext: context,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _controller.focusNode,
        autofocus: true,
        child: GestureDetector(
          onTap: () {
            if (_settingsAnimationController.value > 0.5) {
              _settingsAnimationController.reverse();
            }
          },
          child: PageAwareEnhancedReaderGestureDetector(
            config: _controller.config,
            layout: actualLayout,
            onAction: (action) => _controller.handleAction(action, context),
            onPageZoomChanged: _controller.handlePageZoomChanged,
            onPagePanChanged: (key, offset, alignment) => _controller
                .handlePagePanChanged(key, offset, alignment, context),
            onSwipePage: _controller.swipePage,
            currentPageStateKey: currentPageStateKey,
            leftPageStateKey: leftPageStateKey,
            rightPageStateKey: rightPageStateKey,
            leftPageAlignment: leftPageAlignment,
            rightPageAlignment: rightPageAlignment,
            onGestureHandlerCreated: (handler) {
              _controller.gestureHandler = handler;
            },
            onQueryScale: (key) =>
                _controller.pageTransformManager.getState(key).scale,
            onQueryPan: (key) =>
                _controller.pageTransformManager.getState(key).panOffset,
            child: Stack(
              children: [
                _buildReaderContent(transitionPage),
                // P2-11：控制栏始终挂载，由动画值驱动进出场。
                // 原先用 `if (showControls)` 直接增删节点，hideControls() 里的
                // reverse() 动画没有对象可动，收起是瞬间跳变而非滑动。
                // 隐藏时通过 interactive 关闭命中测试。
                // 注意：IgnorePointer 必须放在控制栏内部 —— 控制栏返回的
                // Positioned 只能是 Stack 的直接子节点。
                ReaderTopControls(
                  animationController: _controlsAnimationController,
                  mangaTitle: widget.manga.title,
                  chapterInfo:
                      '第${_controller.getCurrentChapter().number}章: ${_controller.getCurrentChapter().title}',
                  onBack: () => Navigator.of(context).pop(),
                  interactive: _controller.showControls,
                ),
                ReaderBottomControls(
                  animationController: _controlsAnimationController,
                  currentPage: _controller.currentPage,
                  totalPages: _controller.realPageCount,
                  onPageSliderChanged: (value) {
                    int newPage = value.round();
                    _controller.currentPage = newPage;
                    _controller.notifyExternal();
                    _navigateToPage(newPage);
                  },
                  onSettingsTap: _controller.showSettings,
                  interactive: _controller.showControls,
                ),
                ReaderSettingsPanel(
                  controller: _controller,
                  animationController: _settingsAnimationController,
                ),
                if (_controller.isLoadingNextChapter)
                  const ReaderLoadingOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReaderContent(Widget transitionPage) {
    if (_controller.readingDirection == ReadingDirection.vertical ||
        _controller.readingDirection == ReadingDirection.webtoon) {
      return _buildVerticalReader(transitionPage);
    } else {
      return _buildHorizontalReader(transitionPage);
    }
  }

  Widget _buildHorizontalReader(Widget transitionPage) {
    final actualLayout = _controller.getActualLayout(context);

    if (actualLayout == PageLayout.single) {
      return PageView.builder(
        controller: _controller.pageController,
        onPageChanged: (index) {
          _controller.onPageChanged(context, index, false);
        },
        itemCount: _controller.imageUrls.length,
        reverse: _controller.readingDirection == ReadingDirection.rightToLeft,
        itemBuilder: (context, index) {
          if (_controller.imageUrls[index] ==
              ReaderController.transitionPageMarker) {
            return transitionPage;
          }
          return ReaderImagePage(
            imageUrl: _controller.imageUrls[index],
            controller: _controller,
            parentContext: context,
            pageIndex: index,
          );
        },
      );
    } else {
      // P2-13：不再在 build() 里写 `_controller.pageGroups`（那属于"build 中修改状态"）。
      // 缓存未刷新时（首帧）用本地计算结果渲染，帧后由 refreshPageGroups() 回填。
      final groups = _controller.pageGroups.isNotEmpty
          ? _controller.pageGroups
          : _controller.getPageGroups(context);

      return PageView.builder(
        controller: _controller.pageController,
        onPageChanged: (groupIndex) {
          _controller.onPageChanged(context, groupIndex, true);
        },
        itemCount: groups.length,
        reverse: _controller.readingDirection == ReadingDirection.rightToLeft,
        itemBuilder: (context, groupIndex) {
          return ReaderDoublePage(
            group: groups[groupIndex],
            controller: _controller,
            parentContext: context,
            groupIndex: groupIndex,
            transitionPage: transitionPage,
          );
        },
      );
    }
  }

  Widget _buildVerticalReader(Widget transitionPage) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          // P1-1：页码取"视口顶部所在的页"，位置来自列表项回填的真实布局，
          // 不再用 pixels / screenHeight 估算（每页高度由图片宽高比决定，通常≠屏高）。
          final pageIndex = _controller.resolveVerticalPageIndex();
          if (_controller.currentPage != pageIndex) {
            _controller.onPageChanged(context, pageIndex, false);
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _controller.scrollController,
        scrollDirection: Axis.vertical,
        itemCount: _controller.imageUrls.length,
        itemBuilder: (context, index) {
          final isTransitionPage =
              _controller.imageUrls[index] ==
              ReaderController.transitionPageMarker;
          return _VerticalPageMeasure(
            index: index,
            onMeasured: _controller.reportVerticalPageLayout,
            child: isTransitionPage
                ? transitionPage
                : ReaderImagePage(
                    imageUrl: _controller.imageUrls[index],
                    controller: _controller,
                    parentContext: context,
                    pageIndex: index,
                  ),
          );
        },
      ),
    );
  }

  void _navigateToPage(int page) {
    if (_controller.isVerticalMode) {
      // 竖屏/网漫模式只有 ListView，没有 PageView，必须走 scrollController，
      // 并按目标页的真实偏移定位（P1-1）。
      _controller.goToVerticalPage(page);
      return;
    }
    final pageController = _controller.pageController;
    if (!pageController.hasClients) return;
    final targetIndex = _controller.getGroupIndexForPage(context, page);
    pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goBackToPreviousPage() {
    if (_controller.currentPage > 0) {
      _navigateToPage(_controller.currentPage - 1);
    }
  }
}

/// 竖屏模式下把每个列表项的真实布局位置回填给控制器（P1-1）。
///
/// 竖屏阅读器是连续滚动的 ListView，每项高度由图片宽高比决定；只有拿到真实
/// 偏移才能正确算出"当前是第几页"并精确跳页。这里用 `RenderAbstractViewport`
/// 的 `getOffsetToReveal` 取得该项在滚动坐标系中的顶部偏移。
class _VerticalPageMeasure extends StatefulWidget {
  final int index;
  final void Function(int index, double top, double height) onMeasured;
  final Widget child;

  const _VerticalPageMeasure({
    required this.index,
    required this.onMeasured,
    required this.child,
  });

  @override
  State<_VerticalPageMeasure> createState() => _VerticalPageMeasureState();
}

class _VerticalPageMeasureState extends State<_VerticalPageMeasure> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return widget.child;
  }

  @override
  void didUpdateWidget(covariant _VerticalPageMeasure oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  void _report() {
    if (!mounted) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return;
    final top = viewport.getOffsetToReveal(renderObject, 0.0).offset;
    widget.onMeasured(widget.index, top, renderObject.size.height);
  }
}
