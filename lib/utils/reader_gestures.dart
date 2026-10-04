import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dual_page_utils.dart';

/// 触屏区域类型
enum TouchArea {
  leftEdge,    // 左边缘 (0-20%)
  leftZone,    // 左区域 (20-33%)
  centerZone,  // 中心区域 (33-67%)
  rightZone,   // 右区域 (67-80%)
  rightEdge,   // 右边缘 (80-100%)
}

/// 手势类型
enum GestureType {
  tap,          // 单击
  swipeLeft,    // 左滑
  swipeRight,   // 右滑
  swipeUp,      // 上滑
  swipeDown,    // 下滑
  pinchZoomIn,  // 捏合放大
  pinchZoomOut, // 捏合缩小
}

/// 阅读方向模式
enum ReadingDirection {
  
  rightToLeft,  // 从右到左
  leftToRight,  // 从左到右
  vertical,     // 垂直
  webtoon,      // 网漫模式
}

/// 阅读手势配置
class ReadingGestureConfig {
  final ReadingDirection readingDirection;
  final bool tapToZoom;
  final bool volumeButtonNavigation;
  final bool fullscreenOnTap;
  final bool keepScreenOn;
  final Duration autoHideControlsDelay;
  final bool enableImmersiveMode;

  // 手势动作映射
  final Map<TouchArea, Map<GestureType, String>> gestureActions;

  const ReadingGestureConfig({
    this.readingDirection = ReadingDirection.rightToLeft,
    this.tapToZoom = false,
    this.volumeButtonNavigation = true,
    this.fullscreenOnTap = true,
    this.keepScreenOn = true,
    this.autoHideControlsDelay = const Duration(seconds: 3),
    this.enableImmersiveMode = true,
    this.gestureActions = const {
      TouchArea.leftEdge: {
        GestureType.tap: 'previous_page',
      },
      TouchArea.leftZone: {
        GestureType.tap: 'previous_page',
      },
      TouchArea.centerZone: {
        GestureType.tap: 'toggle_ui',
        GestureType.pinchZoomIn: 'zoom_in',
        GestureType.pinchZoomOut: 'zoom_out',
      },
      TouchArea.rightZone: {
        GestureType.tap: 'next_page',
      },
      TouchArea.rightEdge: {
        GestureType.tap: 'next_page',
      },
    },
  });
}

/// 触觉反馈管理器
class HapticFeedbackManager {
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  static void notificationFeedback(bool success) {
    if (success) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }
}


/// 页面感知型触屏手势处理器
class PageAwareTouchGestureHandler {
  final Function(String stateKey, double scale) onPageZoomChanged;
  final Function(String stateKey, Offset offset, AlignmentGeometry? alignment) onPagePanChanged;
  final Function(bool isForward, Offset velocity)? onSwipePage;
  final Function(TouchArea area, GestureType gesture) onGesture;

  // 起始状态查询回调（由外部提供当前缩放/平移值）
  final double Function(String stateKey)? onQueryScale;
  final Offset Function(String stateKey)? onQueryPan;

  ReadingDirection readingDirection;
  PageLayout pageLayout;

  // 当前手势的起始状态
  double _startScale = 1.0;
  Offset _startPan = Offset.zero;
  Offset _startFocal = Offset.zero;
  Offset _currentPan = Offset.zero;

  // 触屏检测配置
  static const double _edgeThreshold = 0.2;   // 边缘区域阈值
  static const double _centerThreshold = 0.33; // 中心区域阈值

  PageAwareTouchGestureHandler({
    required this.onPageZoomChanged,
    required this.onPagePanChanged,
    required this.onGesture,
    this.onSwipePage,
    this.onQueryScale,
    this.onQueryPan,
    this.readingDirection = ReadingDirection.rightToLeft,
    this.pageLayout = PageLayout.single,
  });

  /// 计算触屏区域
  TouchArea _calculateTouchArea(double screenWidth, double localX) {
    final normalizedX = localX / screenWidth;

    if (normalizedX <= _edgeThreshold) return TouchArea.leftEdge;
    if (normalizedX <= _centerThreshold) return TouchArea.leftZone;
    if (normalizedX <= (1.0 - _centerThreshold)) return TouchArea.centerZone;
    if (normalizedX <= (1.0 - _edgeThreshold)) return TouchArea.rightZone;
    return TouchArea.rightEdge;
  }

  /// 处理点击事件
  void handleTap(double screenWidth, double localX, double localY,
                 String pageKeyForSingle, String leftPageKey, String rightPageKey) {
    final area = _calculateTouchArea(screenWidth, localX);
    onGesture(area, GestureType.tap);
  }

  /// 记录缩放手势起始状态（需在 onScaleStart 中调用）
  void handleScaleStart(String stateKey, Offset focalPoint) {
    _startScale = (onQueryScale?.call(stateKey) ?? 1.0).clamp(0.5, 5.0);
    _startPan = onQueryPan?.call(stateKey) ?? Offset.zero;
    _startFocal = focalPoint;
    _currentPan = _startPan;
  }

  /// 处理带 focal point 感知的缩放 + 平移（需在 onScaleUpdate 中调用）
  void handleScaleUpdate(
    double cumulativeScale, // details.scale 从 1.0 开始累积
    Offset focalPoint,       // details.focalPoint
    String stateKey,
    AlignmentGeometry? alignment,
  ) {
    final newScale = (_startScale * cumulativeScale).clamp(0.5, 5.0);

    final widgetFocal = (_startFocal - _startPan) / _startScale;
    final targetPan = focalPoint - widgetFocal * newScale;
    final deltaPan = targetPan - _currentPan;
    _currentPan = targetPan;

    onPageZoomChanged(stateKey, newScale);
    onPagePanChanged(stateKey, deltaPan, alignment);
  }

  /// 缩放结束 — 取消自动重置，保持当前缩放状态
  void handleZoomEnd(String stateKey, AlignmentGeometry? alignment) {
    // 不再自动重置缩放 — 用户可通过双击或设置面板重置
  }

  /// 释放资源
  void dispose() {}

  /// 设置页面布局
  void setPageLayout(PageLayout layout) {
    pageLayout = layout;
  }
}

/// 页面感知增强阅读手势检测器
class PageAwareEnhancedReaderGestureDetector extends StatefulWidget {
  final Widget child;
  final ReadingGestureConfig config;
  final PageLayout layout;
  final Function(String action) onAction;
  final Function(String stateKey, double scale) onPageZoomChanged;
  final Function(String stateKey, Offset offset, AlignmentGeometry? alignment) onPagePanChanged;
  final Function(bool isForward, Offset velocity)? onSwipePage;
  final Function(PageAwareTouchGestureHandler? gestureHandler)? onGestureHandlerCreated;

  // 缩放/平移当前值查询
  final double Function(String stateKey)? onQueryScale;
  final Offset Function(String stateKey)? onQueryPan;

  // 页面状态信息
  final String currentPageStateKey;
  final String leftPageStateKey;
  final String rightPageStateKey;
  final AlignmentGeometry? leftPageAlignment;
  final AlignmentGeometry? rightPageAlignment;

  const PageAwareEnhancedReaderGestureDetector({
    super.key,
    required this.child,
    required this.config,
    required this.layout,
    required this.onAction,
    required this.onPageZoomChanged,
    required this.onPagePanChanged,
    required this.currentPageStateKey,
    required this.leftPageStateKey,
    required this.rightPageStateKey,
    this.leftPageAlignment,
    this.rightPageAlignment,
    this.onSwipePage,
    this.onGestureHandlerCreated,
    this.onQueryScale,
    this.onQueryPan,
  });

  @override
  State<PageAwareEnhancedReaderGestureDetector> createState() => _PageAwareEnhancedReaderGestureDetectorState();
}

class _PageAwareEnhancedReaderGestureDetectorState extends State<PageAwareEnhancedReaderGestureDetector> {
  late PageAwareTouchGestureHandler _gestureHandler;
  int _pointerCount = 0;
  bool _isTwoFingerGesture = false;
  bool _hadTwoFingerDuringGesture = false;
  int _scaleUpdateCount = 0;
  static const int _swipeMinFrames = 6;
  String _gestureStateKey = '';
  AlignmentGeometry? _gestureAlignment;

  @override
  void initState() {
    super.initState();
    _gestureHandler = PageAwareTouchGestureHandler(
      onPageZoomChanged: widget.onPageZoomChanged,
      onPagePanChanged: widget.onPagePanChanged,
      onGesture: _handleGesture,
      onSwipePage: widget.onSwipePage,
      onQueryScale: widget.onQueryScale,
      onQueryPan: widget.onQueryPan,
      readingDirection: widget.config.readingDirection,
      pageLayout: widget.layout,
    );

    widget.onGestureHandlerCreated?.call(_gestureHandler);

    if (widget.config.keepScreenOn) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void didUpdateWidget(covariant PageAwareEnhancedReaderGestureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // P2-9：handler 只在 initState 里构造一次，方向 / 布局变化时必须同步，
    // 否则在设置面板切换阅读方向或单双页后，划动方向映射仍沿用旧值。
    _gestureHandler.readingDirection = widget.config.readingDirection;
    _gestureHandler.pageLayout = widget.layout;
  }

  void _handleGesture(TouchArea area, GestureType gesture) {
    final action = widget.config.gestureActions[area]?[gesture];
    if (action != null) {
      widget.onAction(action);
    }
  }

  void _resolveGestureTarget(Offset localFocal, double screenWidth) {
    if (widget.layout == PageLayout.single) {
      _gestureStateKey = widget.currentPageStateKey;
      _gestureAlignment = null;
    } else {
      if (localFocal.dx < screenWidth / 2) {
        _gestureStateKey = widget.leftPageStateKey;
        _gestureAlignment = widget.leftPageAlignment;
      } else {
        _gestureStateKey = widget.rightPageStateKey;
        _gestureAlignment = widget.rightPageAlignment;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Listener(
      onPointerDown: (event) {
        _pointerCount++;
        if (_pointerCount >= 2) {
          _isTwoFingerGesture = true;
        }
      },
      onPointerUp: (event) {
        _pointerCount--;
        if (_pointerCount < 2) {
          _isTwoFingerGesture = false;
        }
      },
      onPointerCancel: (event) {
        // P2-8：指针被系统取消（掌拒 / 系统手势 / 切后台）时也必须减计数，
        // 否则 _pointerCount 会永久停在 ≥2，之后单指拖拽会被误判为双指缩放。
        if (_pointerCount > 0) _pointerCount--;
        if (_pointerCount < 2) {
          _isTwoFingerGesture = false;
        }
      },
      child: GestureDetector(
        onTapUp: (details) {
          _gestureHandler.handleTap(
            screenSize.width,
            details.localPosition.dx,
            details.localPosition.dy,
            widget.currentPageStateKey,
            widget.leftPageStateKey,
            widget.rightPageStateKey,
          );
        },

        onScaleStart: (details) {
          _hadTwoFingerDuringGesture = false;
          _scaleUpdateCount = 0;
          _resolveGestureTarget(details.localFocalPoint, screenSize.width);
          _gestureHandler.handleScaleStart(_gestureStateKey, details.focalPoint);
        },
        onScaleUpdate: (details) {
          _scaleUpdateCount++;

          if (_isTwoFingerGesture) {
            _hadTwoFingerDuringGesture = true;
            _gestureHandler.handleScaleUpdate(
              details.scale,
              details.focalPoint,
              _gestureStateKey,
              _gestureAlignment,
            );

            if (details.scale > 1.0) {
              _gestureHandler.onGesture(TouchArea.centerZone, GestureType.pinchZoomIn);
            } else if (details.scale < 1.0) {
              _gestureHandler.onGesture(TouchArea.centerZone, GestureType.pinchZoomOut);
            }
          }

          // P2-10：此处原先把"逐帧"的 focalPointDelta 当作总位移与 80px 阈值比较
          // （单帧位移几乎不可能超过 80px），该翻页路径实际不会触发，却存在同一次
          // 手势内反复触发翻页的风险。慢速拖拽交给子级 PageView / ListView 自身的
          // 滚动物理，快速甩动由下方 onScaleEnd 的速度判定处理，故移除该分支
          // 及其对应的 handlePanUpdate。
        },
        onScaleEnd: (details) {
          if (!_hadTwoFingerDuringGesture && _scaleUpdateCount <= _swipeMinFrames &&
              details.velocity.pixelsPerSecond.dx.abs() > 800) {
            final dx = details.velocity.pixelsPerSecond.dx;
            final isForward = _gestureHandler.readingDirection == ReadingDirection.rightToLeft
                ? dx < 0
                : dx > 0;
            if (widget.onSwipePage != null) {
              widget.onSwipePage!(isForward, details.velocity.pixelsPerSecond);
            }
          }
          _hadTwoFingerDuringGesture = false;
          _scaleUpdateCount = 0;
          _gestureHandler.handleZoomEnd(_gestureStateKey, _gestureAlignment);
        },

        behavior: HitTestBehavior.opaque,
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _gestureHandler.dispose();
    super.dispose();
  }
}
