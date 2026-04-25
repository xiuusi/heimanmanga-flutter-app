import 'package:flutter/material.dart';
import '../../models/manga.dart';
import '../../services/api_service.dart';

class ReaderChapterEndPage extends StatelessWidget {
  final int currentChapterIndex;
  final List<Chapter> chapters;
  final String mangaId;
  final VoidCallback onNextChapter;
  final VoidCallback onGoBack;
  final VoidCallback onExit;

  const ReaderChapterEndPage({
    Key? key,
    required this.currentChapterIndex,
    required this.chapters,
    required this.mangaId,
    required this.onNextChapter,
    required this.onGoBack,
    required this.onExit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isLastChapter = currentChapterIndex >= chapters.length - 1;
    final bool hasNextChapter = currentChapterIndex < chapters.length - 1;
    final Chapter? nextChapter = hasNextChapter ? chapters[currentChapterIndex + 1] : null;

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLastChapter ? Icons.check_circle : Icons.arrow_forward,
              color: const Color(0xFFFF6B6B),
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
                  return const SizedBox.shrink();
                },
              ),
            const SizedBox(height: 32),
            if (hasNextChapter)
              ElevatedButton(
                onPressed: onNextChapter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
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
              onPressed: isLastChapter ? onExit : onGoBack,
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

  Future<int> _getChapterPageCount(Chapter chapter) async {
    try {
      final apiImageFiles = await MangaApiService.getChapterImageFiles(
        mangaId,
        chapter.id,
      );
      return apiImageFiles.length;
    } catch (e) {
      return 0;
    }
  }
}
