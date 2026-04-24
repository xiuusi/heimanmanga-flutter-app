import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 页面变换状态类，用于存储每个页面或半页的独立变换状态
class PageTransformState {
  double scale = 1.0;
  Offset panOffset = Offset.zero;
  Offset cumulativePanOffset = Offset.zero;
  AlignmentGeometry? enforcedAlignment;
  DateTime lastAccessed = DateTime.now();

  PageTransformState();

  /// 重置所有变换状态
  void reset() {
    scale = 1.0;
    panOffset = Offset.zero;
    cumulativePanOffset = Offset.zero;
    lastAccessed = DateTime.now();
  }

  /// 检查是否处于缩放状态
  bool get isZoomed => scale != 1.0;

  /// 检查是否有平移偏移
  bool get hasPanOffset => panOffset != Offset.zero;

  /// 更新最后访问时间
  void updateAccessTime() {
    lastAccessed = DateTime.now();
  }

  /// 应用平移偏移，考虑对齐约束和缩放边界
  void applyPanOffset(Offset delta, {AlignmentGeometry? alignment, Size? viewportSize}) {
    cumulativePanOffset += delta;

    if (alignment != null && alignment is Alignment) {
      if (alignment.x > 0) {
        panOffset = Offset(
          math.max(cumulativePanOffset.dx, 0),
          cumulativePanOffset.dy,
        );
      } else if (alignment.x < 0) {
        panOffset = Offset(
          math.min(cumulativePanOffset.dx, 0),
          cumulativePanOffset.dy,
        );
      } else {
        panOffset = cumulativePanOffset;
      }
    } else {
      panOffset = cumulativePanOffset;
    }

    _clampByViewport(viewportSize);

    updateAccessTime();
  }

  void _clampByViewport(Size? viewportSize) {
    if (viewportSize == null || scale <= 1.0) return;

    final minPanX = viewportSize.width * (1.0 - scale);
    final minPanY = viewportSize.height * (1.0 - scale);
    final overshoot = 0.2;
    final overshootX = viewportSize.width * overshoot;
    final overshootY = viewportSize.height * overshoot;

    panOffset = Offset(
      panOffset.dx.clamp(minPanX - overshootX, overshootX),
      panOffset.dy.clamp(minPanY - overshootY, overshootY),
    );
  }

  /// 应用缩放
  void applyScale(double newScale) {
    scale = newScale.clamp(0.5, 5.0);
    updateAccessTime();
  }

  /// 深拷贝当前状态
  PageTransformState copy() {
    final state = PageTransformState();
    state.scale = scale;
    state.panOffset = panOffset;
    state.cumulativePanOffset = cumulativePanOffset;
    state.enforcedAlignment = enforcedAlignment;
    state.lastAccessed = lastAccessed;
    return state;
  }

  @override
  String toString() {
    return 'PageTransformState(scale: $scale, panOffset: $panOffset, '
        'cumulativePanOffset: $cumulativePanOffset, '
        'isZoomed: $isZoomed, lastAccessed: $lastAccessed)';
  }
}

/// 页面变换状态管理器，用于管理和清理页面状态
class PageTransformManager extends ChangeNotifier {
  final Map<String, PageTransformState> _states = {};
  static const int _maxStates = 20; // 最大缓存状态数
  static const Duration _cleanupInterval = Duration(minutes: 5);

  /// 获取页面状态，如果不存在则创建
  PageTransformState getState(String stateKey, {AlignmentGeometry? alignment}) {
    if (!_states.containsKey(stateKey)) {
      _states[stateKey] = PageTransformState();
    }

    final state = _states[stateKey]!;
    state.updateAccessTime();

    // 如果提供了对齐约束，更新状态中的对齐设置
    if (alignment != null) {
      state.enforcedAlignment = alignment;
    }

    return state;
  }

  /// 更新页面缩放状态
  void updateScale(String stateKey, double scale) {
    final state = getState(stateKey);
    state.applyScale(scale);
    _cleanupIfNeeded();
    notifyListeners();
  }

  /// 更新页面平移状态
  void updatePanOffset(String stateKey, Offset delta, {AlignmentGeometry? alignment, Size? viewportSize}) {
    final state = getState(stateKey);
    state.applyPanOffset(delta, alignment: alignment ?? state.enforcedAlignment, viewportSize: viewportSize);
    _cleanupIfNeeded();
    notifyListeners();
  }

  /// 重置特定页面的状态
  void resetState(String stateKey) {
    _states[stateKey]?.reset();
    notifyListeners();
  }

  /// 重置所有页面状态
  void resetAll() {
    for (final state in _states.values) {
      state.reset();
    }
    notifyListeners();
  }

  /// 清理旧的状态以释放内存
  void cleanupOldStates() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final entry in _states.entries) {
      if (now.difference(entry.value.lastAccessed) > _cleanupInterval) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _states.remove(key);
    }
  }

  /// 如果状态数量超过限制，清理最旧的状态
  void _cleanupIfNeeded() {
    if (_states.length <= _maxStates) {
      return;
    }

    // 找到最旧访问的状态
    var oldestKey = '';
    DateTime oldestTime = DateTime.now();

    for (final entry in _states.entries) {
      if (entry.value.lastAccessed.isBefore(oldestTime)) {
        oldestTime = entry.value.lastAccessed;
        oldestKey = entry.key;
      }
    }

    if (oldestKey.isNotEmpty) {
      _states.remove(oldestKey);
    }
  }

  /// 获取所有状态的统计信息
  Map<String, dynamic> getStats() {
    return {
      'totalStates': _states.length,
      'zoomedStates': _states.values.where((s) => s.isZoomed).length,
      'pannedStates': _states.values.where((s) => s.hasPanOffset).length,
      'oldestState': _states.values
          .map((s) => s.lastAccessed)
          .fold<DateTime>(DateTime.now(), (prev, curr) =>
              curr.isBefore(prev) ? curr : prev),
    };
  }
}