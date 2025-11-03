package io.xiuusi.heimanmanga

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val VOLUME_KEY_CHANNEL = "io.xiuusi.heimanmanga/volume_keys"
    private var shouldInterceptVolumeKeys = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 创建 MethodChannel 用于通信
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOLUME_KEY_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setVolumeKeyInterception" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    shouldInterceptVolumeKeys = enabled
                    println("Android 原生层：音量键拦截状态设置为 $shouldInterceptVolumeKeys")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // 重写 onKeyDown 来拦截音量键
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // 只有在应该拦截音量键时才处理
        if (!shouldInterceptVolumeKeys) {
            return super.onKeyDown(keyCode, event)
        }

        // 音量加键
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            println("Android 原生层：接收到音量加键（已拦截）")
            sendVolumeKeyEventToFlutter("volume_up")
            return true // 返回 true 表示已处理，阻止系统默认行为
        }
        // 音量减键
        else if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            println("Android 原生层：接收到音量减键（已拦截）")
            sendVolumeKeyEventToFlutter("volume_down")
            return true // 返回 true 表示已处理，阻止系统默认行为
        }

        return super.onKeyDown(keyCode, event)
    }

    // 向 Flutter 发送事件
    private fun sendVolumeKeyEventToFlutter(keyType: String) {
        val flutterEngine = this.flutterEngine ?: return

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOLUME_KEY_CHANNEL
        ).invokeMethod("onVolumeKeyPressed", mapOf("key" to keyType))
    }
}
