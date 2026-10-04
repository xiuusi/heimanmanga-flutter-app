import 'package:flutter/material.dart';
import '../../models/manga.dart';
import '../../services/api_service.dart';

class ReaderChapterEndPage extends StatefulWidget {
  final int currentChapterIndex;
  final List<Chapter> chapters;
  final String mangaId;
  final VoidCallback onNextChapter;
  final VoidCallback onGoBack;
  final VoidCallback onExit;

  const ReaderChapterEndPage({
    super.key,
    required this.currentChapterIndex,
    required this.chapters,
    required this.mangaId,
    required this.onNextChapter,
    required this.onGoBack,
    required this.onExit,
  });

  @override
  State<ReaderChapterEndPage> createState() => _ReaderChapterEndPageState();
}

class _ReaderChapterEndPageState extends State<ReaderChapterEndPage> {
  /// 下一章页数请求必须缓存：原先在 build() 里直接创建 Future，
  /// 每次重建都会重新发起一次网络请求，文案也会跟着闪烁（P2-6）。
  Future<int?>? _pageCountFuture;

  @override
  void initState() {
    super.initState();
    _pageCountFuture = _loadNextChapterPageCount();
  }

  @override
  void didUpdateWidget(covariant ReaderChapterEndPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentChapterIndex != widget.currentChapterIndex ||
        oldWidget.mangaId != widget.mangaId) {
      _pageCountFuture = _loadNextChapterPageCount();
    }
  }

  Chapter? get _nextChapter {
    final hasNext = widget.currentChapterIndex < widget.chapters.length - 1;
    return hasNext ? widget.chapters[widget.currentChapterIndex + 1] : null;
  }

  Future<int?> _loadNextChapterPageCount() async {
    final next = _nextChapter;
    if (next == null) return null;
    try {
      final files = await MangaApiService.getChapterImageFiles(
        widget.mangaId,
        next.id,
      );
      return files.isEmpty ? null : files.length;
    } catch (e) {
      // 拉取失败就不显示页数，而不是显示"共 0 页"。
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastChapter =
        widget.currentChapterIndex >= widget.chapters.length - 1;
    final bool hasNextChapter =
        widget.currentChapterIndex < widget.chapters.length - 1;
    final Chapter? nextChapter = _nextChapter;

    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLastChapter ? Icons.check_circle : Icons.arrow_forward,
              color: primary,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              isLastChapter ? '已是最后一章' : '章节结束',
              style: const TextStyle(
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
              FutureBuilder<int?>(
                future: _pageCountFuture,
                builder: (context, snapshot) {
                  final count = snapshot.data;
                  if (count == null || count <= 0) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    '共$count页',
                    style: TextStyle(
                      color: Colors.white.withAlpha(179),
                      fontSize: 14,
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
            if (hasNextChapter)
              ElevatedButton(
                onPressed: widget.onNextChapter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('前往下一章'),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLastChapter ? widget.onExit : widget.onGoBack,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
}
