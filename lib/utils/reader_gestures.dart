import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

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
  doubleTap,    // 双击
  longPress,    // 长按
  tapAndHold,   // 长按并保持
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

  ReadingDirection readingDirection;

  // 触屏检测配置
  static const double _edgeThreshold = 0.2;   // 边缘区域阈值
  static const double _centerThreshold = 0.33; // 中心区域阈值
  static const Duration _doubleTapTime = Duration(milliseconds: 300);
  static const Duration _longPressTime = Duration(milliseconds: 500);

  // 内部状态
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  Timer? _doubleTapTimer;
  Timer? _longPressTimer;
  bool _isLongPressing = false;
  double _currentScale = 1.0;
  double _initialScale = 1.0;

  // 手势状态
  Offset _currentPanOffset = Offset.zero;

  TouchGestureHandler({
    required this.onGesture,
    required this.onZoomChanged,
    required this.onPanChanged,
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
    if (_isLongPressing) {
      _isLongPressing = false;
      return;
    }

    final area = _calculateTouchArea(screenWidth, localX);
    final now = DateTime.now();

    // 检测双击
    if (_lastTapTime != null &&
        _lastTapPosition != null &&
        now.difference(_lastTapTime!) < _doubleTapTime &&
        (Offset(localX, localY) - _lastTapPosition!).distance < 50) {

      _doubleTapTimer?.cancel();
      _lastTapTime = null;
      _lastTapPosition = null;
      onGesture(area, GestureType.doubleTap);
      return;
    }

    _lastTapTime = now;
    _lastTapPosition = Offset(localX, localY);

    // 延迟执行单击以等待可能的第二次点击
    _doubleTapTimer?.cancel();
    _doubleTapTimer = Timer(const Duration(milliseconds: 350), () {
      if (_lastTapTime != null) {
        onGesture(area, GestureType.tap);
        _lastTapTime = null;
        _lastTapPosition = null;
      }
    });
  }

  /// 处理长按事件
  void handleLongPress(double screenWidth, double localX, double localY) {
    final area = _calculateTouchArea(screenWidth, localX);
    _isLongPressing = true;
    onGesture(area, GestureType.longPress);
  }

  /// 处理滑动事件
  void handleSwipe(Offset velocity, double screenWidth, double screenHeight) {
    final velocityX = velocity.dx.abs();
    final velocityY = velocity.dy.abs();

    if (velocityX > velocityY) {
      // 水平滑动
      if (velocity.dx > 0) {
        onGesture(TouchArea.centerZone, GestureType.swipeRight);
      } else {
        onGesture(TouchArea.centerZone, GestureType.swipeLeft);
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

  /// 处理缩放事件（由InteractiveViewer处理）
  void handleZoomChanged(double scale) {
    _currentScale = scale.clamp(0.5, 5.0);
    onZoomChanged(_currentScale);
  }

  /// 释放资源
  void dispose() {
    _doubleTapTimer?.cancel();
    _longPressTimer?.cancel();
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
        GestureType.longPress: 'menu',
      },
      TouchArea.leftZone: {
        GestureType.tap: 'previous_page',
        GestureType.longPress: 'menu',
      },
      TouchArea.centerZone: {
        GestureType.tap: 'toggle_ui',
        GestureType.doubleTap: 'zoom_fit',
        GestureType.longPress: 'menu',
      },
      TouchArea.rightZone: {
        GestureType.tap: 'next_page',
        GestureType.longPress: 'menu',
      },
      TouchArea.rightEdge: {
        GestureType.tap: 'next_page',
        GestureType.longPress: 'menu',
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

  const EnhancedReaderGestureDetector({
    Key? key,
    required this.child,
    required this.config,
    required this.onAction,
    required this.onZoomChanged,
    required this.onPanChanged,
  }) : super(key: key);

  @override
  State<EnhancedReaderGestureDetector> createState() => _EnhancedReaderGestureDetectorState();
}

class _EnhancedReaderGestureDetectorState extends State<EnhancedReaderGestureDetector> {
  late TouchGestureHandler _gestureHandler;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _gestureHandler = TouchGestureHandler(
      onGesture: _handleGesture,
      onZoomChanged: widget.onZoomChanged,
      onPanChanged: widget.onPanChanged,
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

    return GestureDetector(
      // 点击事件
      onTapUp: (details) {
        _gestureHandler.handleTap(
          screenSize.width,
          details.localPosition.dx,
          details.localPosition.dy,
        );
      },

      // 长按事件
      onLongPressStart: (details) {
        _gestureHandler.handleLongPress(
          screenSize.width,
          details.localPosition.dx,
          details.localPosition.dy,
        );
      },

      // 双击事件
      onDoubleTap: () {
        final action = widget.config.gestureActions[TouchArea.centerZone]?[GestureType.doubleTap];
        if (action != null) {
          widget.onAction(action);
        }
      },

      // 简单的拖拽事件（用于翻页）
      onPanEnd: (details) {
        // 检测是否为有效滑动
        final velocity = details.velocity.pixelsPerSecond;
        if (velocity.distance > 300) {
          _gestureHandler.handleSwipe(velocity, screenSize.width, screenSize.height);
        }
      },

      child: widget.child,
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
