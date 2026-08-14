---
kind: dependency_management
name: Flutter Pub 依赖管理（双工程 + 中国镜像锁定）
category: dependency_management
scope:
    - '**'
source_files:
    - coldwallet-app/pubspec.yaml
    - coldwallet-app/pubspec.lock
    - coldwallet-watch/pubspec.yaml
    - coldwallet-watch/pubspec.lock
    - coldwallet-app/.dart_tool/package_config.json
---

## 1. 使用的系统/方法

本项目采用 **Flutter/Dart 官方包管理器 `pub`** 进行依赖声明与解析，使用每个 Flutter 子工程独立的 `pubspec.yaml` + `pubspec.lock` 组合：
- `coldwallet-app/pubspec.yaml` 与 `coldwallet-watch/pubspec.yaml` 分别声明各自应用的直接依赖。
- 对应的 `pubspec.lock` 通过 `sha256` 精确锁定每个包的版本、来源 URL 与哈希值，保证可重复构建。
- 两个工程均设置 `publish_to: 'none'`，表明它们是私有应用，不发布到 pub.dev。
- 未使用 vendoring（无 `packages/` 目录）、无自定义 `pubspec_overrides.yaml`、无全局 `.pub-cache` 配置覆盖；所有第三方包均通过 hosted 源拉取。

## 2. 关键文件

- `coldwallet-app/pubspec.yaml` — 冷钱包离线签名端依赖清单（SDK 约束 `^3.11.1`，核心依赖包括 `cardano_flutter_sdk ^4.0.1`、`cardano_dart_types any`、`bip39_plus ^1.1.1`、`pointycastle ^4.0.0`、`mobile_scanner ^7.4.0`、`flutter_secure_storage ^11.0.0`、`file_picker ^12.0.0-beta.1` 等）。
- `coldwallet-app/pubspec.lock` — 锁定全部直接/间接依赖的精确版本与 `sha256`，且所有包来源 URL 均为 `https://pub.flutter-io.cn`（国内镜像）。
- `coldwallet-watch/pubspec.yaml` — 联网观察端依赖清单（SDK 同样 `^3.11.1`，核心依赖包括 `cardano_flutter_sdk ^4.0.1`、`cardano_dart_types ^3.0.0`、`http ^1.2.0`、`shared_preferences ^2.3.0`、`intl ^0.19.0`、`mobile_scanner ^3.0.0` 等）。
- `coldwallet-watch/pubspec.lock` — 对应锁定文件（同样走 `pub.flutter-io.cn`）。
- `coldwallet-app/.dart_tool/package_config.json` / `package_graph.json` — Dart 工具生成的本地包解析缓存，不参与版本控制。

## 3. 架构与约定

- **多工程独立依赖**：冷钱包 App 与 Watch 端是相互独立的 Flutter 工程，各自维护自己的 `pubspec.yaml` 与 `pubspec.lock`，不存在共享的 workspace 或 monorepo 级别的依赖聚合。这意味着两个工程的依赖可以不同步（例如 watch 用 `cardano_dart_types ^3.0.0`，app 用 `any`），升级时需分别处理。
- **版本约束策略**：
  - 大部分依赖使用 caret 范围（如 `^4.0.1`、`^11.0.0`），允许小版本/补丁自动升级。
  - `cardano_dart_types` 在 app 中写为 `any`（宽松），在 watch 中写为 `^3.0.0`（较严格），体现对同一库的不同容忍度。
  - `file_picker` 在 app 中为 `^12.0.0-beta.1`，在 watch 中为 `^12.0.0-beta.7`，显示两个工程处于不同的 beta 阶段。
- **构建环境**：两个工程都通过 `environment.sdk: ^3.11.1` 锁定 Dart SDK 主版本，避免跨大版本兼容问题。
- **网络源**：从 lock 文件中可见所有包均来自 `https://pub.flutter-io.cn`，说明开发者通过环境变量或 `~/.config/dart/pub-config.json` 将默认源切换为中国镜像，以加速下载。

## 4. 约定与约束

- **禁止发布**：两个 `pubspec.yaml` 均显式设置 `publish_to: 'none'`，约束这两个工程不会被误发布到公共仓库。
- **锁文件必须提交**：`pubspec.lock` 存在于两个工程中，意味着团队约定通过提交 lock 文件来固定依赖树，保证 CI 和本地构建一致。
- **无私有注册表/GOPRIVATE**：未发现任何私有 registry 配置、`dependency_overrides` 或 `git:` 路径依赖；所有第三方包均来自托管源。
- **无 vendoring**：仓库中没有 `vendor/`、`third_party/` 或 `packages/` 形式的源码级依赖拷贝，依赖完全由 `pub` 解析并缓存至本地 `.dart_tool`。
- **Android Gradle 依赖**：原生层依赖由 Android Gradle 管理（`android/build.gradle.kts`、`android/app/build.gradle.kts`），与 Dart 依赖解耦；本仓库未见统一的 Gradle 版本锁定脚本，仅包含 Gradle Wrapper。
- **升级方式**：根据 `pubspec.yaml` 中的注释，推荐通过 `flutter pub upgrade --major-versions` 或手动修改版本号后运行 `flutter pub get` 更新依赖，并由 `pubspec.lock` 固化结果。