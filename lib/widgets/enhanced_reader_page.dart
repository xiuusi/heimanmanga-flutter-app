import 'package:flutter/material.dart';
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
    Key? key,
    required this.manga,
    required this.chapter,
    required this.chapters,
    this.initialConfig,
  }) : super(key: key);

  @override
  _EnhancedReaderPageState createState() => _EnhancedReaderPageState();
}

class _EnhancedReaderPageState extends State<EnhancedReaderPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late ReaderController _controller;
  late AnimationController _settingsAnimationController;
  late AnimationController _controlsAnimationController;

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
    _controller.disposeController();
    _settingsAnimationController.dispose();
    _controlsAnimationController.dispose();
    _controller.removeListener(_onControllerChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actualLayout = _controller.getActualLayout(context);

    String currentPageStateKey = 'page_${_controller.currentPage}';
    String leftPageStateKey = '';
    String rightPageStateKey = '';
    AlignmentGeometry? leftPageAlignment;
    AlignmentGeometry? rightPageAlignment;

    if (actualLayout == PageLayout.double && _controller.pageGroups.isNotEmpty) {
      final currentGroupIndex = _controller.currentGroupIndex.clamp(
        0, _controller.pageGroups.length - 1);
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
            onPagePanChanged: (key, offset, alignment) =>
                _controller.handlePagePanChanged(key, offset, alignment, context),
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
                if (_controller.showControls)
                  ReaderTopControls(
                    animationController: _controlsAnimationController,
                    mangaTitle: widget.manga.title,
                    chapterInfo: '第${_controller.getCurrentChapter().number}章: ${_controller.getCurrentChapter().title}',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                if (_controller.showControls)
                  ReaderBottomControls(
                    animationController: _controlsAnimationController,
                    currentPage: _controller.currentPage,
                    totalPages: _controller.imageUrls.length,
                    onPageSliderChanged: (value) {
                      int newPage = value.round();
                      _controller.currentPage = newPage;
                      _controller.notifyExternal();
                      _navigateToPage(newPage);
                    },
                    onSettingsTap: _controller.showSettings,
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
      _controller.pageGroups = _controller.getPageGroups(context);

      return PageView.builder(
        controller: _controller.pageController,
        onPageChanged: (groupIndex) {
          _controller.onPageChanged(context, groupIndex, true);
        },
        itemCount: _controller.pageGroups.length,
        reverse: _controller.readingDirection == ReadingDirection.rightToLeft,
        itemBuilder: (context, groupIndex) {
          return ReaderDoublePage(
            group: _controller.pageGroups[groupIndex],
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
          final screenHeight = MediaQuery.of(context).size.height;
          final currentPage = (notification.metrics.pixels / screenHeight)
              .floor()
              .clamp(0, _controller.imageUrls.length - 1);

          if (_controller.currentPage != currentPage) {
            _controller.onPageChanged(context, currentPage, false);
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _controller.scrollController,
        scrollDirection: Axis.vertical,
        itemCount: _controller.imageUrls.length,
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
      ),
    );
  }

  void _navigateToPage(int page) {
    if (_controller.readingDirection == ReadingDirection.vertical ||
        _controller.readingDirection == ReadingDirection.webtoon) {
      _controller.scrollController.animateTo(
        page * MediaQuery.of(context).size.height,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      final targetIndex = _controller.getGroupIndexForPage(context, page);
      _controller.pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goBackToPreviousPage() {
    if (_controller.currentPage > 0) {
      _navigateToPage(_controller.currentPage - 1);
    }
  }
}
