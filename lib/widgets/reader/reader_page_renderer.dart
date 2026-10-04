import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/manga.dart';
import '../../services/api_service.dart';
import '../../utils/dual_page_utils.dart';
import '../../utils/reader_gestures.dart';
import 'reader_controller.dart';
import 'reader_chapter_end_page.dart';

class ReaderImageContent extends StatelessWidget {
  final String imageUrl;
  final ReaderController controller;
  final AlignmentGeometry? alignment;
  final int? pageIndex;
  final int? groupIndex;
  final int? pageInGroup;
  final bool applyTransform;
  final BuildContext parentContext;

  const ReaderImageContent({
    super.key,
    required this.imageUrl,
    required this.controller,
    required this.parentContext,
    this.alignment,
    this.pageIndex,
    this.groupIndex,
    this.pageInGroup,
    this.applyTransform = true,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == ReaderController.transitionPageMarker) {
      return const SizedBox.shrink();
    }

    final Map<String, String>? httpHeaders = MangaApiService.userAgent.isNotEmpty
        ? {'User-Agent': MangaApiService.userAgent}
        : null;

    // 找不到 URL（例如图片列表刚被替换）时不要退化成 0 —— 那会与真正的第 0 页
    // 共用同一份缩放/平移状态。退化到当前页，状态键仍然唯一（P3）。
    var actualPageIndex = pageIndex ?? controller.imageUrls.indexOf(imageUrl);
    if (actualPageIndex < 0) {
      actualPageIndex = controller.currentPage;
    }

    final stateKey = controller.getPageStateKey(
      parentContext,
      actualPageIndex,
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
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.primary, size: 50),
              const SizedBox(height: 10),
              const Text('图片加载失败',
                style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
      httpHeaders: httpHeaders,
    );

    if (alignment != null) {
      imageWidget = Align(alignment: alignment!, child: imageWidget);
    }

    if (applyTransform) {
      return ListenableBuilder(
        listenable: controller.pageTransformManager,
        builder: (context, _) {
          final s = controller.pageTransformManager.getState(
            stateKey,
            alignment: alignment,
          );
          return Transform(
            transform: Matrix4.identity()
              ..translateByDouble(s.panOffset.dx, s.panOffset.dy, 0.0, 1.0)
              ..scaleByDouble(s.scale, s.scale, s.scale, 1.0),
            child: imageWidget,
          );
        },
      );
    } else {
      return imageWidget;
    }
  }
}

class ReaderImagePage extends StatelessWidget {
  final String imageUrl;
  final ReaderController controller;
  final BuildContext parentContext;
  final int? pageIndex;

  const ReaderImagePage({
    super.key,
    required this.imageUrl,
    required this.controller,
    required this.parentContext,
    this.pageIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == ReaderController.transitionPageMarker) {
      return const SizedBox.shrink();
    }
    return Container(
      color: Colors.black,
      child: ReaderImageContent(
        imageUrl: imageUrl,
        controller: controller,
        parentContext: parentContext,
        pageIndex: pageIndex,
      ),
    );
  }
}

class ReaderDoublePage extends StatelessWidget {
  final PageGroup group;
  final ReaderController controller;
  final BuildContext parentContext;
  final int? groupIndex;
  final Widget transitionPage;

  const ReaderDoublePage({
    super.key,
    required this.group,
    required this.controller,
    required this.parentContext,
    required this.transitionPage,
    this.groupIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (group.urls.isNotEmpty &&
        group.urls[0] == ReaderController.transitionPageMarker) {
      return transitionPage;
    }

    final isRTL = controller.readingDirection == ReadingDirection.rightToLeft;
    final leftPageIndex = isRTL ? 1 : 0;
    final rightPageIndex = isRTL ? 0 : 1;

    final actualGroupIndex = groupIndex ??
        controller.getGroupIndexForPage(parentContext, leftPageIndex);
    final stateKey = 'group_$actualGroupIndex';

    Widget doublePageContent = Container(
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            // P2-7：放大左半页时不能画到右半页上。
            child: ClipRect(
              child: _buildPageInGroup(
                group, leftPageIndex, isRTL,
                alignment: Alignment.centerRight,
                groupIndex: actualGroupIndex,
                applyTransform: false,
              ),
            ),
          ),
          Container(width: 1.51, color: Colors.black),
          Expanded(
            child: ClipRect(
              child: _buildPageInGroup(
                group, rightPageIndex, isRTL,
                alignment: Alignment.centerLeft,
                groupIndex: actualGroupIndex,
                applyTransform: false,
              ),
            ),
          ),
        ],
      ),
    );

    return ListenableBuilder(
      listenable: controller.pageTransformManager,
      builder: (context, _) {
        final s = controller.pageTransformManager.getState(stateKey);
        // P2-7：整体变换后再裁一次，避免放大后溢出到屏幕外。
        return ClipRect(
          child: Transform(
            transform: Matrix4.identity()
              ..translateByDouble(s.panOffset.dx, s.panOffset.dy, 0.0, 1.0)
              ..scaleByDouble(s.scale, s.scale, s.scale, 1.0),
            child: doublePageContent,
          ),
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
    return ReaderImageContent(
      imageUrl: url,
      controller: controller,
      parentContext: parentContext,
      alignment: alignment,
      groupIndex: groupIndex,
      pageInGroup: index,
      applyTransform: applyTransform,
    );
  }
}

class ReaderTransitionPage extends StatelessWidget {
  final ReaderController controller;
  final List<Chapter> chapters;
  final String mangaId;
  final VoidCallback onGoBack;
  final BuildContext parentContext;

  const ReaderTransitionPage({
    super.key,
    required this.controller,
    required this.chapters,
    required this.mangaId,
    required this.onGoBack,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return ReaderChapterEndPage(
      currentChapterIndex: controller.currentChapterIndex,
      chapters: chapters,
      mangaId: mangaId,
      onNextChapter: () {
        final nextIdx = controller.currentChapterIndex + 1;
        if (nextIdx < chapters.length) {
          controller.loadNextChapter(parentContext, nextIdx);
        }
      },
      onGoBack: onGoBack,
      onExit: () => Navigator.of(context).pop(),
    );
  }
}
