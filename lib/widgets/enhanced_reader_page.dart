import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import '../services/reading_progress_service.dart';
import '../utils/reader_gestures.dart';
import '../utils/image_cache_manager.dart';
import 'dart:async';
import 'dart:math' as math;

/// 增强版阅读器页面（Mihon风格）
class EnhancedReaderPage extends StatefulWidget {
  final Manga manga;
  final Chapter chapter;
  final ReadingGestureConfig? initialConfig;

  const EnhancedReaderPage({
    Key? key,
    required this.manga,
    required this.chapter,
    this.initialConfig,
  }) : super(key: key);

  @override
  _EnhancedReaderPageState createState() => _EnhancedReaderPageState();
}

class _EnhancedReaderPageState extends State<EnhancedReaderPage>
    with TickerProviderStateMixin {
  // 基础控制器
  late PageController _pageController;
  late ScrollController _scrollController;

  // 阅读状态
  int _currentPage = 0;
  bool _showControls = true;
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _imageUrls = [];

  // UI状态
  Timer? _hideTimer;
  bool _isInFullscreen = false;
  bool _showSettingsPanel = false;

  // 缩放和拖拽
  double _currentScale = 1.0;
  double _initialScale = 1.0;
  Offset _panOffset = Offset.zero;
  bool _isZoomed = false;

  // 配置
  late ReadingGestureConfig _config;
  ReadingDirection _readingDirection = ReadingDirection.rightToLeft;

  // 动画控制器
  late AnimationController _settingsAnimationController;
  late AnimationController _controlsAnimationController;

  // 预加载
  Set<int> _preloadedPages = <int>{};
  static const int _preloadRange = 3;

  // 阅读进度
  double _readingProgress = 0.0;
  Timer? _progressSaveTimer;

  // 阅读进度管理器
  final ReadingProgressManager _progressManager = ReadingProgressManager();
  ReadingProgress? _existingProgress;
  bool _hasShownJumpPrompt = false;

  @override
  void initState() {
    super.initState();

    // 初始化配置
    _config = widget.initialConfig ?? ReadingGestureConfig();
    _readingDirection = _config.readingDirection;
    
    

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
      await _progressManager.init();
      _existingProgress = await _progressManager.getProgress(widget.manga.id);

      if (_existingProgress != null && mounted) {
        // 检查是否需要显示跳转提示
        if (_existingProgress!.shouldPromptJump()) {
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

  /// 跳转到进度位置
  void _jumpToProgress() {
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

  /// 保存阅读进度
  Future<void> _saveReadingProgress() async {
    if (_imageUrls.isEmpty) {
      return;
    }

    try {
      await _progressManager.saveProgress(
        manga: widget.manga,
        chapter: widget.chapter,
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

    for (int i = start; i <= end; i++) {
      if (!_preloadedPages.contains(i)) {
        _preloadedPages.add(i);
        precacheImage(
          CachedNetworkImageProvider(_imageUrls[i]),
          context,
          onError: (exception, stackTrace) {
            _preloadedPages.remove(i);
          },
        );
      }
    }
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
      case 'zoom_fit':
        _toggleZoom();
        break;
      case 'menu':
        _showSettings();
        break;
      case 'settings':
        _showSettings();
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

  void _toggleZoom() {
    HapticFeedbackManager.lightImpact();
    setState(() {
      if (_isZoomed) {
        _currentScale = 1.0;
        _isZoomed = false;
        _panOffset = Offset.zero;
      } else {
        _currentScale = 2.0;
        _isZoomed = true;
      }
    });
  }

  void _previousPage() {
    if (_currentPage > 0) {
      HapticFeedbackManager.selectionClick();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _imageUrls.length - 1) {
      HapticFeedbackManager.selectionClick();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  
  void _showSettings() {
    HapticFeedbackManager.mediumImpact();
    _settingsAnimationController.forward();
  }




  @override
  void dispose() {
    // 退出时保存最终进度
    _saveReadingProgress();

    _pageController.dispose();
    _scrollController.dispose();
    _hideTimer?.cancel();
    _progressSaveTimer?.cancel();
    _settingsAnimationController.dispose();
    _controlsAnimationController.dispose();

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
      body: GestureDetector(
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
            _isZoomed = scale > 1.0;
          });
        },
        onPanChanged: (offset) {
          setState(() {
            _panOffset = offset;
          });
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
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
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
      },
      itemCount: _imageUrls.length,
      reverse: _readingDirection == ReadingDirection.rightToLeft,
      itemBuilder: (context, index) {
        return _buildImagePage(_imageUrls[index]);
      },
    );
  }

  Widget _buildVerticalReader() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          // 计算当前页面
          final screenHeight = MediaQuery.of(context).size.height;
          final currentPage = (notification.metrics.pixels / screenHeight).floor().clamp(0, _imageUrls.length - 1);

          if (_currentPage != currentPage) {
            setState(() {
              _currentPage = currentPage;
              _readingProgress = currentPage / (_imageUrls.length - 1);
            });
            // 滚动页面切换时保存进度
            _saveReadingProgress();
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
    return Container(
      color: Colors.black,
      child: InteractiveViewer(
        panEnabled: _isZoomed,
        boundaryMargin: EdgeInsets.all(100),
        minScale: 0.5,
        maxScale: 4.0,
        transformationController: TransformationController(),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
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
        ),
      ),
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
                  Colors.black.withOpacity(0.8),
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
                  child: Text(
                    '${widget.manga.title} - 第${widget.chapter.number}章',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
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
                  Colors.black.withOpacity(0.8),
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
                    overlayColor: Color(0xFFFF6B6B).withOpacity(0.2),
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
              color: Colors.black.withOpacity(0.95),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
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
              ],
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
          color: isSelected ? Color(0xFFFF6B6B).withOpacity(0.2) : Colors.transparent,
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

}
