import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// release 签名凭据存放在 android/key.properties（已被 .gitignore 忽略，不入库）。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "io.xiuusi.heimanmanga"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.xiuusi.heimanmanga"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 必须使用真实 release 密钥签名。
            // 若 android/key.properties 缺失，下面的 taskGraph 校验会让 release 构建
            // 明确失败，绝不静默回退到公开的 Android debug 密钥。
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // 启用 R8 代码压缩与资源裁剪；Flutter 引擎/插件的 keep 规则见 proguard-rules.pro
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // 修改APK输出文件名，包含版本号和架构信息
    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this
            if (output is com.android.build.gradle.internal.api.ApkVariantOutputImpl) {
                val abi = output.getFilter(com.android.build.OutputFile.ABI)
                val version = variant.versionName
                val variantName = variant.name

                val fileName = if (abi != null) {
                    // 包含架构的分ABI APK
                    "heimanmanga-${version}-${abi}-${variantName}.apk"
                } else {
                    // 通用APK（不含架构信息）
                    "heimanmanga-${version}-${variantName}.apk"
                }
                output.outputFileName = fileName
            }
        }
    }
}

// 只在真正要打 release 包时校验签名凭据，避免影响 debug 构建与 IDE 同步。
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { it.name.contains("Release") }
    if (buildingRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "缺少 android/key.properties：release 包必须使用真实签名密钥，" +
                "不会回退到公开的 Android debug 密钥。请按 README「发布签名」一节创建该文件。"
        )
    }
}

flutter {
    source = "../.."
}
