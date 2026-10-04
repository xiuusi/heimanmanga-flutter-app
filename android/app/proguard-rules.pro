# Flutter release 构建的 R8/ProGuard 规则。
# Flutter 引擎类通过 JNI 与反射访问，禁止压缩/混淆，否则 release 包会在启动时崩溃。
-keep class io.flutter.** { *; }

# 插件（library）依赖 embedding（program），R8 会报缺失类警告。
-dontwarn io.flutter.plugin.**

# android.** 由系统在运行时提供。
-dontwarn android.**

# Flutter embedding 引用了 Play Core 的 deferred components API，但本应用未依赖
# play-core（不做动态功能分发），因此这些类在编译期不存在 —— R8 会报 Missing class。
# 规则由 AGP 在 build/app/outputs/mapping/release/missing_rules.txt 中自动生成。
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# R8 在部分场景会错误裁剪 FlutterPlugin 实现，参考 flutter/flutter#154580。
-if class * implements io.flutter.embedding.engine.plugins.FlutterPlugin
-keep,allowshrinking,allowobfuscation class <1>
