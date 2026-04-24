import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
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


/// 触屏手势处理器
class TouchGestureHandler {
  final Function(TouchArea area, GestureType gesture) onGesture;
  final Function(double scale) onZoomChanged;
  final Function(Offset offset) onPanChanged;
  final Function(bool isForward, Offset velocity)? onSwipePage;

  ReadingDirection readingDirection;

  // 触屏检测配置
  static const double _edgeThreshold = 0.2;   // 边缘区域阈值
  static const double _centerThreshold = 0.33; // 中心区域阈值

  // 内部状态
  double _currentScale = 1.0;
  Timer? _zoomResetTimer;
  static const Duration _zoomResetDelay = Duration(seconds: 10);

  TouchGestureHandler({
    required this.onGesture,
    required this.onZoomChanged,
    required this.onPanChanged,
    this.onSwipePage,
    this.readingDirection = ReadingDirection.rightToLeft,
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
  void handleTap(double screenWidth, double localX, double localY) {
    final area = _calculateTouchArea(screenWidth, localX);
    onGesture(area, GestureType.tap);
  }


  /// 处理滑动事件
  void handleSwipe(Offset velocity, double screenWidth, double screenHeight) {
    final velocityX = velocity.dx.abs();
    final velocityY = velocity.dy.abs();

    if (velocityX > velocityY) {
      // 水平滑动
      if (velocity.dx > 0) {
        // 向右滑动
        if (onSwipePage != null) {
          onSwipePage!(false, velocity); // 向左翻页（从右到左阅读方向）
        } else {
          onGesture(TouchArea.centerZone, GestureType.swipeRight);
        }
      } else {
        // 向左滑动
        if (onSwipePage != null) {
          onSwipePage!(true, velocity); // 向右翻页（从右到左阅读方向）
        } else {
          onGesture(TouchArea.centerZone, GestureType.swipeLeft);
        }
      }
    } else {
      // 垂直滑动
      if (velocity.dy > 0) {
        onGesture(TouchArea.centerZone, GestureType.swipeDown);
      } else {
        onGesture(TouchArea.centerZone, GestureType.swipeUp);
      }
    }
  }

  /// 处理平移事件（用于检测水平滑动）
  void handlePanUpdate(Offset translation, Offset focalPoint, double screenWidth) {
    // 检测是否为有效的水平滑动
    if (translation.dx.abs() > 80) {
      // 根据阅读方向判断翻页方向
      if (readingDirection == ReadingDirection.rightToLeft) {
        // 从右到左阅读：向右滑动是上一页，向左滑动是下一页
        if (translation.dx > 0 && onSwipePage != null) {
          onSwipePage!(false, translation); // 上一页
        } else if (translation.dx < 0 && onSwipePage != null) {
          onSwipePage!(true, translation); // 下一页
        }
      } else {
        // 从左到右阅读：向右滑动是下一页，向左滑动是上一页
        if (translation.dx > 0 && onSwipePage != null) {
          onSwipePage!(true, translation); // 下一页
        } else if (translation.dx < 0 && onSwipePage != null) {
          onSwipePage!(false, translation); // 上一页
        }
      }
    }
  }


  /// 处理缩放事件
  void handleZoomChanged(double scale) {
    _currentScale = scale.clamp(0.5, 5.0);
    onZoomChanged(_currentScale);
  }

  /// 处理缩放状态下的平移事件（移动图片）
  void handlePanInZoom(Offset translation) {
    onPanChanged(translation);
  }

  /// 处理缩放结束事件
  void handleZoomEnd() {
    // 取消之前的重置计时器
    _zoomResetTimer?.cancel();

    // 如果当前缩放比例不是1.0，则启动延迟重置计时器
    if (_currentScale != 1.0) {
      _zoomResetTimer = Timer(_zoomResetDelay, () {
        // 延迟10秒后重置缩放和平移状态
        _currentScale = 1.0;
        onZoomChanged(_currentScale);
        onPanChanged(Offset.zero);
      });
    } else {
      // 如果已经是1.0，立即重置
      _currentScale = 1.0;
      onZoomChanged(_currentScale);
      onPanChanged(Offset.zero);
    }
  }

  /// 取消缩放重置计时器（用于页面切换等情况）
  void cancelZoomReset() {
    _zoomResetTimer?.cancel();
    _zoomResetTimer = null;
  }

  /// 释放资源
  void dispose() {
    _zoomResetTimer?.cancel();
    _zoomResetTimer = null;
  }
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

/// 增强的阅读手势检测器
class EnhancedReaderGestureDetector extends StatefulWidget {
  final Widget child;
  final ReadingGestureConfig config;
  final Function(String action) onAction;
  final Function(double scale) onZoomChanged;
  final Function(Offset offset) onPanChanged;
  final Function(bool isForward, Offset velocity)? onSwipePage;
  final Function(TouchGestureHandler? gestureHandler)? onGestureHandlerCreated;

  const EnhancedReaderGestureDetector({
    Key? key,
    required this.child,
    required this.config,
    required this.onAction,
    required this.onZoomChanged,
    required this.onPanChanged,
    this.onSwipePage,
    this.onGestureHandlerCreated,
  }) : super(key: key);

  @override
  State<EnhancedReaderGestureDetector> createState() => _EnhancedReaderGestureDetectorState();
}

class _EnhancedReaderGestureDetectorState extends State<EnhancedReaderGestureDetector> {
  late TouchGestureHandler _gestureHandler;
  double _currentScale = 1.0;
  int _pointerCount = 0;
  bool _isTwoFingerGesture = false;
  bool _hadTwoFingerDuringGesture = false;
  int _scaleUpdateCount = 0;
  static const int _swipeMinFrames = 6;

  @override
  void initState() {
    super.initState();
    _gestureHandler = TouchGestureHandler(
      onGesture: _handleGesture,
      onZoomChanged: widget.onZoomChanged,
      onPanChanged: widget.onPanChanged,
      onSwipePage: widget.onSwipePage,
      readingDirection: widget.config.readingDirection,
    );

    // 通知父组件手势处理器已创建
    widget.onGestureHandlerCreated?.call(_gestureHandler);

    // 保持屏幕常亮
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

  void _handleGesture(TouchArea area, GestureType gesture) {
    final action = widget.config.gestureActions[area]?[gesture];
    if (action != null) {
      widget.onAction(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Listener(
      onPointerDown: (event) {
        _pointerCount++;
        // 当检测到两个或更多触摸点时，标记为双指手势
        if (_pointerCount >= 2) {
          _isTwoFingerGesture = true;
        }
      },
      onPointerUp: (event) {
        _pointerCount--;
        // 当触摸点少于2个时，重置双指手势标记
        if (_pointerCount < 2) {
          _isTwoFingerGesture = false;
        }
      },
      child: GestureDetector(
        // 点击事件
        onTapUp: (details) {
          _gestureHandler.handleTap(
            screenSize.width,
            details.localPosition.dx,
            details.localPosition.dy,
          );
        },

        // 捏合手势
        onScaleStart: (details) {
          _currentScale = 1.0;
          _hadTwoFingerDuringGesture = false;
          _scaleUpdateCount = 0;
        },
      onScaleUpdate: (details) {
        _scaleUpdateCount++;

        if (_isTwoFingerGesture && details.scale != 1.0) {
          _hadTwoFingerDuringGesture = true;
          _currentScale = details.scale.clamp(0.5, 5.0);
          _gestureHandler.handleZoomChanged(_currentScale);

          if (details.scale > 1.0) {
            _gestureHandler.onGesture(TouchArea.centerZone, GestureType.pinchZoomIn);
          } else {
            _gestureHandler.onGesture(TouchArea.centerZone, GestureType.pinchZoomOut);
          }
        }

        if (details.focalPointDelta != Offset.zero) {
          if (_currentScale != 1.0 && _isTwoFingerGesture) {
            _gestureHandler.handlePanInZoom(details.focalPointDelta);
          } else if (!_hadTwoFingerDuringGesture && _scaleUpdateCount > _swipeMinFrames) {
            _gestureHandler.handlePanUpdate(
              details.focalPointDelta,
              details.focalPoint,
              screenSize.width
            );
          }
        }
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
        _gestureHandler.handleZoomEnd();
      },

      // 水平滑动检测（通过ScaleGestureRecognizer的平移分量）
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
  double _currentScale = 1.0;
  String _activePageKey = '';

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

  /// 更新活动页面键（根据触摸位置和布局模式）
  void _updateActivePageKey(double screenWidth, double localX, String pageKeyForSingle,
                           String leftPageKey, String rightPageKey) {
    if (pageLayout == PageLayout.single) {
      _activePageKey = pageKeyForSingle;
    } else if (pageLayout == PageLayout.double) {
      // 双页模式：根据触摸位置确定左右页面
      _activePageKey = (localX < screenWidth / 2) ? leftPageKey : rightPageKey;
    } else {
      _activePageKey = pageKeyForSingle;
    }
  }

  /// 处理点击事件
  void handleTap(double screenWidth, double localX, double localY,
                 String pageKeyForSingle, String leftPageKey, String rightPageKey) {
    _updateActivePageKey(screenWidth, localX, pageKeyForSingle, leftPageKey, rightPageKey);
    final area = _calculateTouchArea(screenWidth, localX);
    onGesture(area, GestureType.tap);
  }

  /// 处理滑动事件
  void handleSwipe(Offset velocity, double screenWidth, double screenHeight) {
    final velocityX = velocity.dx.abs();
    final velocityY = velocity.dy.abs();

    if (velocityX > velocityY) {
      // 水平滑动
      if (velocity.dx > 0) {
        // 向右滑动
        if (onSwipePage != null) {
          onSwipePage!(false, velocity); // 向左翻页（从右到左阅读方向）
        } else {
          onGesture(TouchArea.centerZone, GestureType.swipeRight);
        }
      } else {
        // 向左滑动
        if (onSwipePage != null) {
          onSwipePage!(true, velocity); // 向右翻页（从右到左阅读方向）
        } else {
          onGesture(TouchArea.centerZone, GestureType.swipeLeft);
        }
      }
    } else {
      // 垂直滑动
      if (velocity.dy > 0) {
        onGesture(TouchArea.centerZone, GestureType.swipeDown);
      } else {
        onGesture(TouchArea.centerZone, GestureType.swipeUp);
      }
    }
  }

  /// 处理平移事件（用于检测水平滑动）
  void handlePanUpdate(Offset translation, Offset focalPoint, double screenWidth) {
    // 检测是否为有效的水平滑动
    if (translation.dx.abs() > 80) {
      // 根据阅读方向判断翻页方向
      if (readingDirection == ReadingDirection.rightToLeft) {
        // 从右到左阅读：向右滑动是上一页，向左滑动是下一页
        if (translation.dx > 0 && onSwipePage != null) {
          onSwipePage!(false, translation); // 上一页
        } else if (translation.dx < 0 && onSwipePage != null) {
          onSwipePage!(true, translation); // 下一页
        }
      } else {
        // 从左到右阅读：向右滑动是下一页，向左滑动是上一页
        if (translation.dx > 0 && onSwipePage != null) {
          onSwipePage!(true, translation); // 下一页
        } else if (translation.dx < 0 && onSwipePage != null) {
          onSwipePage!(false, translation); // 上一页
        }
      }
    }
  }

  /// 记录缩放手势起始状态（需在 onScaleStart 中调用）
  void handleScaleStart(String stateKey, Offset focalPoint) {
    _startScale = (onQueryScale?.call(stateKey) ?? 1.0).clamp(0.5, 5.0);
    _startPan = onQueryPan?.call(stateKey) ?? Offset.zero;
    _startFocal = focalPoint;
    _currentPan = _startPan;
    _currentScale = _startScale;
    _activePageKey = stateKey;
  }

  /// 处理带 focal point 感知的缩放 + 平移（需在 onScaleUpdate 中调用）
  void handleScaleUpdate(
    double cumulativeScale, // details.scale 从 1.0 开始累积
    Offset focalPoint,       // details.focalPoint
    String stateKey,
    AlignmentGeometry? alignment,
  ) {
    final newScale = (_startScale * cumulativeScale).clamp(0.5, 5.0);
    _currentScale = newScale;

    final widgetFocal = (_startFocal - _startPan) / _startScale;
    final targetPan = focalPoint - widgetFocal * newScale;
    final deltaPan = targetPan - _currentPan;
    _currentPan = targetPan;

    onPageZoomChanged(stateKey, newScale);
    onPagePanChanged(stateKey, deltaPan, alignment);
  }

  /// 处理缩放下的纯平移（手指拖动时 focalPoint 已变化，需额外补量）
  /// 正常情况下 handleScaleUpdate 已涵盖，此方法为纯平移补充
  void handlePanInZoom(Offset delta, String stateKey, AlignmentGeometry? alignment) {
    _currentPan += delta;
    onPagePanChanged(stateKey, delta, alignment);
  }

  /// 缩放结束 — 取消自动重置，保持当前缩放状态
  void handleZoomEnd(String stateKey, AlignmentGeometry? alignment) {
    // 不再自动重置缩放 — 用户可通过双击或设置面板重置
  }

  /// 取消缩放重置计时器（保留为空以兼容旧调用）
  void cancelZoomReset() {}

  /// 释放资源
  void dispose() {}

  /// 设置页面布局
  void setPageLayout(PageLayout layout) {
    pageLayout = layout;
  }

  /// 获取当前活动页面键
  String getActivePageKey() {
    return _activePageKey;
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
    Key? key,
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
  }) : super(key: key);

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

          if (details.focalPointDelta != Offset.zero
              && !_isTwoFingerGesture
              && !_hadTwoFingerDuringGesture
              && _scaleUpdateCount > _swipeMinFrames) {
            _gestureHandler.handlePanUpdate(
              details.focalPointDelta,
              details.focalPoint,
              screenSize.width,
            );
          }
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
