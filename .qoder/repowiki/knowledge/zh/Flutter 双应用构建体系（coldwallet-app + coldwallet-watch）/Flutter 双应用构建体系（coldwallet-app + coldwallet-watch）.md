---
kind: build_system
name: Flutter 双应用构建体系（coldwallet-app + coldwallet-watch）
category: build_system
scope:
    - '**'
source_files:
    - coldwallet-app/pubspec.yaml
    - coldwallet-watch/pubspec.yaml
    - coldwallet-app/android/app/build.gradle.kts
    - coldwallet-watch/android/app/build.gradle.kts
    - coldwallet-app/analysis_options.yaml
    - coldwallet-watch/analysis_options.yaml
    - coldwallet-app/android/.gitignore
    - coldwallet-watch/android/.gitignore
---

## 1. 使用的构建系统

本项目采用 **Flutter + Android Gradle** 的官方构建方案，包含两个独立的 Flutter 应用模块：
- `coldwallet-app`：离线冷钱包签名端（Android 应用）
- `coldwallet-watch`：联网观察客户端（Android 应用）

每个子项目均为标准 Flutter 工程结构，通过各自的 `pubspec.yaml` 管理 Dart/Flutter 依赖，通过 `android/app/build.gradle.kts` 调用 Gradle 插件完成 Android APK 构建。没有顶层 Makefile、Dockerfile、CI 流水线或自定义构建脚本，构建完全依赖 `flutter build` / `flutter run` 与 Gradle。

## 2. 关键文件

- `coldwallet-app/pubspec.yaml`：定义应用名 `coldwallet_app`、版本 `1.0.0+1`、SDK 约束 `^3.11.1`、依赖（`cardano_flutter_sdk ^4.0.1`、`bip39_plus`、`mobile_scanner`、`qr_flutter`、`flutter_secure_storage` 等），并设置 `publish_to: 'none'` 禁止发布到 pub.dev。
- `coldwallet-watch/pubspec.yaml`：定义应用名 `coldwallet_watch`、相同 SDK 约束、依赖（`cardano_flutter_sdk ^4.0.1`、`http`、`shared_preferences`、`intl` 等），同样禁止发布。
- `coldwallet-app/android/app/build.gradle.kts`：声明 `com.android.application`、`kotlin-android`、`dev.flutter.flutter-gradle-plugin`；`compileSdk = 37`、`JavaVersion.VERSION_17`、`namespace = com.coldwallet.coldwallet_app`、`applicationId = com.coldwallet.coldwallet_app`；`release` 构建类型当前复用 debug signingConfig。
- `coldwallet-watch/android/app/build.gradle.kts`：结构与上者一致，仅 namespace/applicationId 为 `com.coldwallet.coldwallet_watch`。
- `coldwallet-app/analysis_options.yaml` 与 `coldwallet-watch/analysis_options.yaml`：均 `include: package:flutter_lints/flutter.yaml`，启用 Flutter 官方 lint 规则集。
- `coldwallet-app/.gitignore` / `coldwallet-watch/.gitignore`：忽略 `build/`、`.dart_tool/`、`*.iml`、`gradlew*`、`local.properties` 等生成物。

## 3. 架构与约定

- **双应用并列结构**：仓库根下并列放置 `coldwallet-app` 与 `coldwallet-watch` 两个独立 Flutter 工程，互不引用，各自维护自己的 `pubspec.yaml`、`lib/`、`android/`、`test/`。
- **版本策略**：两个应用的 `version` 字段统一使用 `1.0.0+1`（`pubspec.yaml` 注释说明 `--build-name` 对应 versionName/CFBundleShortVersionString，`--build-number` 对应 versionCode/CFBundleVersion），可通过 `flutter build --build-name/--build-number` 覆盖。
- **Android 构建配置**：两个应用共享相同的 Gradle 模板——`compileSdk = 37`、`sourceCompatibility/targetCompatibility/jvmTarget = JavaVersion.VERSION_17`、`minSdk/targetSdk` 通过 `flutter.minSdkVersion` / `flutter.targetSdkVersion` 注入、`release` 构建类型默认使用 debug key 签名（注释提示需替换为正式签名配置）。
- **Lint 规范**：两工程共用 `flutter_lints/flutter.yaml` 作为基线，未做额外规则定制。
- **依赖锁定**：各工程目录下存在 `pubspec.lock`，用于固定依赖版本。

## 4. 约定与约束

- **无 CI/CD 与自动化构建脚本**：仓库中不存在 `.github/workflows`、Jenkinsfile、Makefile、Dockerfile 或顶层 `build.sh`；构建与发布目前为手动执行 `flutter build apk` / `flutter build appbundle` 的方式。
- **禁止发布到 pub.dev**：两个 `pubspec.yaml` 均显式设置 `publish_to: 'none'`，约束这两个工程不作为公共包发布。
- **Release 签名尚未配置**：`android/app/build.gradle.kts` 中 `release` 构建类型使用 `signingConfigs.getByName("debug")`，注释明确标注“需添加正式的 signing config”，因此正式发布前必须配置签名。
- **Gradle Wrapper 被忽略**：`android/.gitignore` 忽略 `gradlew` / `gradlew.bat`，意味着 Gradle Wrapper 不在版本控制中，构建环境需自行安装 Gradle 或使用 Flutter 自带的 Gradle 分发。
- **Android NDK 版本由 Flutter 注入**：`ndkVersion = flutter.ndkVersion`，NDK 版本跟随 Flutter SDK 而非硬编码。
- **分析/测试入口**：代码质量检查通过 `flutter analyze`（基于 `analysis_options.yaml`），单元测试通过 `flutter test`（位于各工程的 `test/` 目录）。