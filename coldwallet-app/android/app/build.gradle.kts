plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.coldwallet.coldwallet_app"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.coldwallet.coldwallet_app"
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

    // Release 产物命名为「应用名-v版本号.apk」，冷钱包 APK 靠手动传输分发，
    // 文件名带版本号是防装旧版的唯一线索；debug 构建保持默认名
    applicationVariants.all {
        outputs.all {
            if (buildType.name == "release") {
                val output =
                    this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
                output.outputFileName = "Stasis-v${versionName}.apk"
            }
        }
    }
}

flutter {
    source = "../.."
}
