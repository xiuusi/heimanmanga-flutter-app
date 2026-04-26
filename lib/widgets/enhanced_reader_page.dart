import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import '../utils/reader_gestures.dart';
import '../utils/dual_page_utils.dart';
import 'reader/reader_controller.dart';
import 'reader/reader_settings_panel.dart';
import 'reader/reader_chapter_end_page.dart';

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
      final currentGroupIndex = _controller.currentGroupIndex.clamp(0, _controller.pageGroups.length - 1);
      currentPageStateKey = 'group_$currentGroupIndex';
      leftPageStateKey = currentPageStateKey;
      rightPageStateKey = currentPageStateKey;
      leftPageAlignment = Alignment.centerRight;
      rightPageAlignment = Alignment.centerLeft;
    }

    if (_controller.isLoading) {
      return _buildLoadingState();
    }

    if (_controller.errorMessage != null) {
      return _buildErrorState();
    }

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
            onQueryScale: (key) => _controller.pageTransformManager.getState(key).scale,
            onQueryPan: (key) => _controller.pageTransformManager.getState(key).panOffset,
            child: Stack(
              children: [
                _buildReaderContent(),
                if (_controller.showControls) _buildTopControls(),
                if (_controller.showControls) _buildBottomControls(),
                ReaderSettingsPanel(
                  controller: _controller,
                  animationController: _settingsAnimationController,
                ),
                if (_controller.isLoadingNextChapter) _buildLoadingOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
            const SizedBox(height: 20),
            const Text(
              '正在加载章节...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: primary, size: 60),
            const SizedBox(height: 20),
            Text(
              _controller.errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _controller.loadChapterImages(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
            const SizedBox(height: 20),
            const Text(
              '正在加载下一章...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderContent() {
    if (_controller.readingDirection == ReadingDirection.vertical ||
        _controller.readingDirection == ReadingDirection.webtoon) {
      return _buildVerticalReader();
    } else {
      return _buildHorizontalReader();
    }
  }

  Widget _buildHorizontalReader() {
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
          return _buildImagePage(_controller.imageUrls[index], pageIndex: index);
        },
      );
    } else {
      _controller.pageGroups = _getPageGroups();

      return PageView.builder(
        controller: _controller.pageController,
        onPageChanged: (groupIndex) {
          _controller.onPageChanged(context, groupIndex, true);
        },
        itemCount: _controller.pageGroups.length,
        reverse: _controller.readingDirection == ReadingDirection.rightToLeft,
        itemBuilder: (context, groupIndex) {
          final group = _controller.pageGroups[groupIndex];
          return _buildDoublePage(group, groupIndex: groupIndex);
        },
      );
    }
  }

  Widget _buildVerticalReader() {
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
          return _buildImagePage(_controller.imageUrls[index], pageIndex: index);
        },
      ),
    );
  }

  Widget _buildImagePage(String imageUrl, {int? pageIndex}) {
    if (imageUrl == ReaderController.transitionPageMarker) {
      return _buildTransitionPage();
    }
    return Container(
      color: Colors.black,
      child: _buildImageContent(imageUrl, pageIndex: pageIndex),
    );
  }

  Widget _buildImageContent(String imageUrl, {
    AlignmentGeometry? alignment,
    int? pageIndex,
    int? groupIndex,
    int? pageInGroup,
    bool applyTransform = true,
  }) {
    if (imageUrl == ReaderController.transitionPageMarker) {
      return _buildTransitionPage();
    }

    final Map<String, String>? httpHeaders = MangaApiService.userAgent.isNotEmpty
        ? {'User-Agent': MangaApiService.userAgent}
        : null;

    int actualPageIndex = pageIndex ?? _controller.imageUrls.indexOf(imageUrl);
    if (actualPageIndex == -1) {
      actualPageIndex = 0;
    }

    final stateKey = _controller.getPageStateKey(context, actualPageIndex,
      groupIndex: groupIndex,
      pageInGroup: pageInGroup,
    );

    final isDoublePageImage = groupIndex != null;

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: isDoublePageImage ? BoxFit.fitWidth : BoxFit.contain,
      placeholder: (context, url) => Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.primary, size: 50),
              const SizedBox(height: 10),
              const Text('图片加载失败', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
      httpHeaders: httpHeaders,
    );

    if (alignment != null) {
      imageWidget = Align(alignment: alignment, child: imageWidget);
    }

    if (applyTransform) {
      return ListenableBuilder(
        listenable: _controller.pageTransformManager,
        builder: (context, _) {
          final s = _controller.pageTransformManager.getState(stateKey, alignment: alignment);
          return Transform(
            transform: Matrix4.identity()
              ..translate(s.panOffset.dx, s.panOffset.dy)
              ..scale(s.scale),
            child: imageWidget,
          );
        },
      );
    } else {
      return imageWidget;
    }
  }

  Widget _buildDoublePage(PageGroup group, {int? groupIndex}) {
    if (group.urls.isNotEmpty && group.urls[0] == ReaderController.transitionPageMarker) {
      return _buildTransitionPage();
    }

    final isRTL = _controller.readingDirection == ReadingDirection.rightToLeft;
    final leftPageIndex = isRTL ? 1 : 0;
    final rightPageIndex = isRTL ? 0 : 1;

    final actualGroupIndex = groupIndex ?? _controller.getGroupIndexForPage(context, leftPageIndex);
    final stateKey = 'group_$actualGroupIndex';

    Widget doublePageContent = Container(
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: _buildPageInGroup(
              group, leftPageIndex, isRTL,
              alignment: Alignment.centerRight,
              groupIndex: actualGroupIndex,
              applyTransform: false,
            ),
          ),
          Container(width: 1.51, color: Colors.black),
          Expanded(
            child: _buildPageInGroup(
              group, rightPageIndex, isRTL,
              alignment: Alignment.centerLeft,
              groupIndex: actualGroupIndex,
              applyTransform: false,
            ),
          ),
        ],
      ),
    );

    return ListenableBuilder(
      listenable: _controller.pageTransformManager,
      builder: (context, _) {
        final s = _controller.pageTransformManager.getState(stateKey);
        return Transform(
          transform: Matrix4.identity()
            ..translate(s.panOffset.dx, s.panOffset.dy)
            ..scale(s.scale),
          child: doublePageContent,
        );
      },
    );
  }

  Widget _buildPageInGroup(PageGroup group, int index, bool isRTL, {
    AlignmentGeometry? alignment,
    int? groupIndex,
    bool applyTransform = true,
  }) {
    if (index >= group.urls.length || group.urls[index] == null) {
      return Container(color: Colors.black);
    }

    final url = group.urls[index]!;
    return _buildImageContent(url,
      alignment: alignment,
      groupIndex: groupIndex,
      pageInGroup: index,
      applyTransform: applyTransform,
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
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.manga.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '第${_controller.getCurrentChapter().number}章: ${_controller.getCurrentChapter().title}',
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
    final primary = Theme.of(context).colorScheme.primary;
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
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: primary,
                    inactiveTrackColor: Colors.grey[600],
                    thumbColor: primary,
                    overlayColor: primary.withAlpha(51),
                    trackHeight: 4.0,
                  ),
                  child: Slider(
                    value: _controller.currentPage.toDouble(),
                    min: 0,
                    max: (_controller.imageUrls.length - 1).toDouble(),
                    onChanged: (value) {
                      int newPage = value.round();
                      _controller.currentPage = newPage;
                      _controller.notifyExternal();

                      if (_controller.readingDirection == ReadingDirection.vertical ||
                          _controller.readingDirection == ReadingDirection.webtoon) {
                        _controller.scrollController.animateTo(
                          newPage * MediaQuery.of(context).size.height,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        final targetIndex = _controller.getGroupIndexForPage(context, newPage);
                        _controller.pageController.animateToPage(
                          targetIndex,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '第 ${_controller.currentPage + 1}/${_controller.imageUrls.length} 页',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: _controller.showSettings,
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

  Widget _buildTransitionPage() {
    return ReaderChapterEndPage(
      currentChapterIndex: _controller.currentChapterIndex,
      chapters: widget.chapters,
      mangaId: widget.manga.id,
      onNextChapter: () {
        final nextIdx = _controller.currentChapterIndex + 1;
        if (nextIdx < widget.chapters.length) {
          _controller.loadNextChapter(context, nextIdx);
        }
      },
      onGoBack: _goBackToPreviousPage,
      onExit: () => Navigator.of(context).pop(),
    );
  }

  void _goBackToPreviousPage() {
    if (_controller.currentPage > 0) {
      final targetPage = _controller.currentPage - 1;

      if (_controller.readingDirection == ReadingDirection.vertical ||
          _controller.readingDirection == ReadingDirection.webtoon) {
        _controller.scrollController.animateTo(
          targetPage * MediaQuery.of(context).size.height,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        final targetIndex = _controller.getGroupIndexForPage(context, targetPage);
        _controller.pageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  List<PageGroup> _getPageGroups() {
    final isLandscape = DualPageUtils.isLandscape(context);
    final hasTransitionPage = _controller.imageUrls.isNotEmpty &&
        _controller.imageUrls.last == ReaderController.transitionPageMarker;

    List<String> pagesForGrouping;
    if (hasTransitionPage) {
      pagesForGrouping = _controller.imageUrls.sublist(0, _controller.imageUrls.length - 1);
    } else {
      pagesForGrouping = List.from(_controller.imageUrls);
    }

    final groups = DualPageUtils.groupPages(pagesForGrouping, _controller.dualPageConfig, isLandscape);

    if (hasTransitionPage) {
      groups.add(PageGroup(
        index: groups.length,
        urls: [ReaderController.transitionPageMarker],
      ));
    }

    return groups;
  }
}
