import 'package:flutter/services.dart';

/// 音量键控制器
class VolumeKeyController {
  static const platform = MethodChannel('io.xiuusi.heimanmanga/volume_keys');
  bool volumeButtonNavigationEnabled = false;
  bool isChannelListenerSetup = false;
  
  Function()? onPreviousPage;
  Function()? onNextPage;

  VolumeKeyController({this.volumeButtonNavigationEnabled = false});

  /// 设置音量键监听
  void setupVolumeKeyListener() {
    if (isChannelListenerSetup || !volumeButtonNavigationEnabled) {
      return;
    }

    // 设置方法调用处理器
    platform.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onVolumeKeyPressed') {
        final String key = call.arguments['key'];

        if (key == 'volume_up') {
          onPreviousPage?.call();
        } else if (key == 'volume_down') {
          onNextPage?.call();
        }
      }
    });

    isChannelListenerSetup = true;
  }

  /// 启用或禁用音量键拦截
  Future<void> enableVolumeKeyInterception(bool enabled) async {
    try {
      await platform.invokeMethod('setVolumeKeyInterception', {
        'enabled': enabled,
      });
    } catch (e) {
      // 设置音量键拦截失败
    }
  }
}