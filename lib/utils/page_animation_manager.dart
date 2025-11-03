import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 翻页动画管理器
class PageAnimationManager {
  static final PageAnimationManager _instance = PageAnimationManager._internal();
  factory PageAnimationManager() => _instance;
  PageAnimationManager._internal();

  // 动画配置
  static const Duration _baseAnimationDuration = Duration(milliseconds: 280);
  static const Duration _fastAnimationDuration = Duration(milliseconds: 180);
  static const Duration _slowAnimationDuration = Duration(milliseconds: 400);

  // 滑动速度阈值
  static const double _fastSwipeThreshold = 800.0; // 像素/秒
  static const double _slowSwipeThreshold = 300.0; // 像素/秒

  /// 根据滑动速度计算动画持续时间
  Duration calculateAnimationDuration(Offset velocity) {
    final speed = velocity.distance;

    if (speed > _fastSwipeThreshold) {
      return _fastAnimationDuration;
    } else if (speed < _slowSwipeThreshold) {
      return _slowAnimationDuration;
    } else {
      // 线性插值
      final ratio = (speed - _slowSwipeThreshold) / (_fastSwipeThreshold - _slowSwipeThreshold);
      final durationMs = _slowAnimationDuration.inMilliseconds +
          ratio * (_fastAnimationDuration.inMilliseconds - _slowAnimationDuration.inMilliseconds);
      return Duration(milliseconds: durationMs.round());
    }
  }

  /// 根据滑动速度计算缓动曲线
  Curve calculateAnimationCurve(Offset velocity, bool isForward) {
    final speed = velocity.distance;

    if (speed > _fastSwipeThreshold) {
      // 快速滑动使用更激进的缓动曲线
      return Curves.fastOutSlowIn;
    } else if (speed < _slowSwipeThreshold) {
      // 慢速滑动使用更平滑的缓动曲线
      return Curves.easeInOut;
    } else {
      // 中等速度使用标准缓动曲线
      return Curves.easeInOut;
    }
  }

  /// 获取点击翻页的动画配置
  PageAnimationConfig getTapAnimationConfig() {
    return PageAnimationConfig(
      duration: _baseAnimationDuration,
      curve: Curves.easeInOut,
      type: AnimationType.tap,
    );
  }

  /// 获取滑动翻页的动画配置
  PageAnimationConfig getSwipeAnimationConfig(Offset velocity, bool isForward) {
    return PageAnimationConfig(
      duration: calculateAnimationDuration(velocity),
      curve: calculateAnimationCurve(velocity, isForward),
      type: AnimationType.swipe,
      velocity: velocity,
    );
  }

  /// 获取跳转动画配置
  PageAnimationConfig getJumpAnimationConfig() {
    return PageAnimationConfig(
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      type: AnimationType.jump,
    );
  }
}

/// 动画类型
enum AnimationType {
  tap,    // 点击翻页
  swipe,  // 滑动翻页
  jump,   // 跳转翻页
}

/// 翻页动画配置
class PageAnimationConfig {
  final Duration duration;
  final Curve curve;
  final AnimationType type;
  final Offset? velocity;

  const PageAnimationConfig({
    required this.duration,
    required this.curve,
    required this.type,
    this.velocity,
  });

  @override
  String toString() {
    return 'PageAnimationConfig(duration: $duration, curve: $curve, type: $type, velocity: $velocity)';
  }
}

/// 物理翻页模拟器
class PhysicsPageSimulator {
  /// 模拟物理翻页效果
  static double simulatePageTurn(double progress, Curve curve, {bool reverse = false}) {
    // 应用缓动曲线
    final easedProgress = curve.transform(progress);

    // 添加轻微的物理效果
    if (!reverse) {
      // 正向翻页：轻微加速然后减速
      return easedProgress;
    } else {
      // 反向翻页：不同的物理效果
      return easedProgress;
    }
  }

  /// 计算基于速度的动画进度
  static double calculateVelocityBasedProgress(double progress, double velocity) {
    // 根据速度调整动画进度曲线
    final normalizedVelocity = velocity.clamp(0.0, 1.0);

    if (normalizedVelocity > 0.7) {
      // 高速：更线性的进度
      return progress;
    } else if (normalizedVelocity < 0.3) {
      // 低速：更平滑的进度
      return math.sin(progress * math.pi / 2);
    } else {
      // 中等速度：混合效果
      final linearPart = progress * 0.7;
      final smoothPart = math.sin(progress * math.pi / 2) * 0.3;
      return linearPart + smoothPart;
    }
  }
}

/// 动画性能监控器
class AnimationPerformanceMonitor {
  static final AnimationPerformanceMonitor _instance = AnimationPerformanceMonitor._internal();
  factory AnimationPerformanceMonitor() => _instance;
  AnimationPerformanceMonitor._internal();

  final List<double> _frameTimes = [];
  static const int _maxSamples = 60; // 约1秒的数据

  /// 记录帧时间
  void recordFrameTime(double frameTimeMs) {
    _frameTimes.add(frameTimeMs);

    // 保持最近的数据
    if (_frameTimes.length > _maxSamples) {
      _frameTimes.removeAt(0);
    }
  }

  /// 获取平均帧时间
  double getAverageFrameTime() {
    if (_frameTimes.isEmpty) return 16.67; // 60fps

    final sum = _frameTimes.reduce((a, b) => a + b);
    return sum / _frameTimes.length;
  }

  /// 检查是否帧率过低
  bool isFrameRateLow() {
    final avgFrameTime = getAverageFrameTime();
    return avgFrameTime > 33.33; // 低于30fps
  }

  /// 获取推荐的动画持续时间
  Duration getRecommendedAnimationDuration() {
    final avgFrameTime = getAverageFrameTime();

    if (avgFrameTime > 25.0) {
      // 帧率较低，使用更短的动画
      return Duration(milliseconds: 200);
    } else if (avgFrameTime > 20.0) {
      // 中等帧率
      return Duration(milliseconds: 250);
    } else {
      // 高帧率，使用标准动画
      return Duration(milliseconds: 280);
    }
  }

  /// 清理数据
  void clear() {
    _frameTimes.clear();
  }
}