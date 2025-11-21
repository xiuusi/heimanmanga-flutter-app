import 'dart:async';
import 'package:flutter/material.dart';

/// UI 控制器
class UIController {
  // UI状态
  bool showControls = true;
  Timer? hideTimer;
  bool isSettingsPanelOpen = false;

  // 动画控制器
  late AnimationController settingsAnimationController;
  late AnimationController controlsAnimationController;

  // 配置
  Duration autoHideControlsDelay = const Duration(seconds: 3);

  /// 初始化UI控制器
  void initialize(TickerProvider vsync) {
    settingsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: vsync,
    );
    controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: vsync,
    );
    // 设置动画值，避免在动画期间重建UI
    controlsAnimationController.value = 1.0; // 初始显示
  }

  /// 开始自动隐藏计时器
  void startHideTimer() {
    hideTimer?.cancel();
    hideTimer = Timer(autoHideControlsDelay, () {
      if (showControls) {
        hideControls();
      }
    });
  }

  /// 隐藏控制栏
  void hideControls() {
    showControls = false;
    controlsAnimationController.reverse();
  }

  /// 显示控制栏
  void showControlsTemporarily() {
    showControls = true;
    controlsAnimationController.forward();
    startHideTimer();
  }

  /// 切换UI显示状态
  void toggleUI() {
    if (showControls) {
      hideControls();
    } else {
      showControlsTemporarily();
    }
  }

  /// 显示设置面板
  void showSettings() {
    settingsAnimationController.forward();
    isSettingsPanelOpen = true;
  }

  /// 隐藏设置面板
  void hideSettings() {
    settingsAnimationController.reverse();
    isSettingsPanelOpen = false;
  }

  /// 销毁控制器
  void dispose() {
    hideTimer?.cancel();
    settingsAnimationController.dispose();
    controlsAnimationController.dispose();
  }
}