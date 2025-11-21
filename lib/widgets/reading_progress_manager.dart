import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../services/reading_progress_service.dart';

/// 阅读进度管理器
class ReadingProgressManager {
  final ReadingProgressService _progressService = ReadingProgressService();
  ReadingProgress? _existingProgress;
  bool _hasShownJumpPrompt = false;
  late final Manga manga;
  late final Chapter chapter;
  Function(int)? _onProgressUpdate;
  Function(int, int)? _onChapterMarkedAsRead;

  ReadingProgressManager({
    required this.manga,
    required this.chapter,
    Function(int)? onProgressUpdate,
    Function(int, int)? onChapterMarkedAsRead,
  }) {
    _onProgressUpdate = onProgressUpdate;
    _onChapterMarkedAsRead = onChapterMarkedAsRead;
  }

  /// 加载阅读进度
  Future<void> loadReadingProgress() async {
    try {
      await _progressService.init();
      _existingProgress = await _progressService.getProgress(manga.id, chapterId: chapter.id);
    } catch (e) {
      // 加载阅读进度失败
    }
  }

  /// 显示跳转到进度的提示
  Future<void> showJumpToProgressPrompt(BuildContext context, {required int totalPages, required Function(int) onJump}) async {
    if (_hasShownJumpPrompt || _existingProgress == null) return;

    final currentPage = _existingProgress!.currentPage + 1;
    final percentage = (_existingProgress!.readingPercentage * 100).toStringAsFixed(1);

    return showDialog(
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
              onJump(_existingProgress!.currentPage);
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

  /// 标记当前章节为已阅读
  Future<void> markCurrentChapterAsRead() async {
    try {
      await _progressService.markChapterAsRead(
        mangaId: manga.id,
        chapterId: chapter.id,
        isRead: true,
      );
      
      _onChapterMarkedAsRead?.call(int.tryParse(manga.id) ?? 0, int.tryParse(chapter.id) ?? 0);
    } catch (e) {
      // 自动标记章节失败
    }
  }

  /// 保存阅读进度
  Future<void> saveReadingProgress({required int currentPage, required int totalPages}) async {
    try {
      await _progressService.saveProgress(
        manga: manga,
        chapter: chapter,
        currentPage: currentPage,
        totalPages: totalPages,
      );
      
      _onProgressUpdate?.call(currentPage);
    } catch (e) {
      // 保存阅读进度失败
    }
  }

  /// 获取当前进度百分比
  double getProgressPercentage(int currentPage, int totalPages) {
    if (totalPages == 0) return 0.0;
    return currentPage / totalPages;
  }

  /// 检查是否需要显示跳转提示
  bool shouldShowJumpPrompt() {
    return _existingProgress != null && _existingProgress!.shouldPromptJump(chapter.id);
  }

  /// 获取存在的进度
  ReadingProgress? get existingProgress => _existingProgress;
}