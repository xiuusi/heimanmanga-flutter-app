plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

flutter {
    source = "../.."
}
