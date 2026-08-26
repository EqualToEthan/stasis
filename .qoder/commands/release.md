---
description: 构建 Release APK。可选参数：app / watch，不指定则两个都打
---
## 概述

为 Flutter 子项目构建 Release APK。根据用户输入的参数决定构建目标：

| 用户输入 | 构建目标 |
|---------|----------|
| `/release` | coldwallet-app + coldwallet-watch（可并行） |
| `/release app` | 仅 coldwallet-app |
| `/release watch` | 仅 coldwallet-watch |

## 执行步骤

1. **构建 Release APK**
   - coldwallet-app：`cd coldwallet-app && flutter build apk --release`
   - coldwallet-watch：`cd coldwallet-watch && flutter build apk --release`
   - 两个项目同时构建时使用 `is_background: true` 并行执行

2. **输出结果**
   - 报告 APK 文件路径和大小
   - 构建失败时报告错误并尝试修复

## 构建产物

APK 文件名由各子项目 `android/app/build.gradle.kts` 的输出命名配置生成（应用名-v版本号，版本号取自 pubspec.yaml 的 version；debug 构建保持默认名 app-debug.apk）：

| 子项目 | APK 路径 |
|--------|--------|
| coldwallet-app | `coldwallet-app/build/app/outputs/flutter-apk/Stasis-v{versionName}.apk`（如 `Stasis-v1.0.0.apk`） |
| coldwallet-watch | `coldwallet-watch/build/app/outputs/flutter-apk/Stasis-Link-v{versionName}.apk`（如 `Stasis-Link-v1.0.0.apk`） |
