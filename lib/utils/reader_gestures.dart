import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    if (translation.dx.abs() > 20) {
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
    // 缩放结束，重置缩放和平移状态
    _currentScale = 1.0;
    onZoomChanged(_currentScale);
    onPanChanged(Offset.zero);
  }

  /// 释放资源
  void dispose() {
    // 清理资源
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
    this.volumeButtonNavigation = false,
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

  const EnhancedReaderGestureDetector({
    Key? key,
    required this.child,
    required this.config,
    required this.onAction,
    required this.onZoomChanged,
    required this.onPanChanged,
    this.onSwipePage,
  }) : super(key: key);

  @override
  State<EnhancedReaderGestureDetector> createState() => _EnhancedReaderGestureDetectorState();
}

class _EnhancedReaderGestureDetectorState extends State<EnhancedReaderGestureDetector> {
  late TouchGestureHandler _gestureHandler;
  double _currentScale = 1.0;
  int _pointerCount = 0; // 记录当前触摸点数量
  bool _isTwoFingerGesture = false; // 标记是否为双指手势

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
        },
      onScaleUpdate: (details) {
        // 只有在双指手势时才处理缩放
        if (_isTwoFingerGesture && details.scale != 1.0) {
          _currentScale = details.scale.clamp(0.5, 5.0);
          _gestureHandler.handleZoomChanged(_currentScale);

          // 检测捏合方向
          if (details.scale > 1.0) {
            _gestureHandler.onGesture(TouchArea.centerZone, GestureType.pinchZoomIn);
          } else {
            _gestureHandler.onGesture(TouchArea.centerZone, GestureType.pinchZoomOut);
          }
        }

        // 处理平移：在缩放状态下也可以移动图片
        if (details.focalPointDelta != Offset.zero) {
          // 如果是缩放状态下的平移，传递给平移处理
          if (_currentScale != 1.0 && _isTwoFingerGesture) {
            _gestureHandler.handlePanInZoom(details.focalPointDelta);
          } else {
            // 非缩放状态下的平移，用于水平滑动翻页
            _gestureHandler.handlePanUpdate(
              details.focalPointDelta,
              details.focalPoint,
              screenSize.width
            );
          }
        }
      },
      onScaleEnd: (details) {
        // 缩放结束，触发自动恢复原样
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
