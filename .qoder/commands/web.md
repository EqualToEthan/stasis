---
description: 启动 Flutter Web 开发服务器。可选参数：watch，不指定默认启动 app
---
## 概述

为 Flutter 子项目启动 Web 开发服务器（web-server 模式），用于快速 UI 迭代。固定端口，不自动打开浏览器，用户手动访问 URL。

| 用户输入 | 启动目标 | 访问地址 |
|---------|----------|---------|
| `/web` | coldwallet-app | http://localhost:8080 |
| `/web watch` | coldwallet-watch | http://localhost:8081 |

## 执行步骤

1. **停止已有的 Flutter 进程**
   - 执行 `taskkill /f /im dart.exe 2>$null`
   - 避免端口冲突

2. **启动 Web Server（后台运行）**
   - coldwallet-app：`cd coldwallet-app && flutter run -d web-server --web-port 8080`
   - coldwallet-watch：`cd coldwallet-watch && flutter run -d web-server --web-port 8081`
   - 使用 `is_background: true` 在后台运行

3. **等待服务就绪**
   - 使用 GetTerminalOutput 检查终端输出
   - 等待出现 `is being served at` 或 `Debug service listening` 字样

4. **输出结果**
   - 告知用户访问 URL（http://localhost:8080 或 8081）
   - 提醒用户在终端按 `r` 热重载、按 `R` 热重启

## 使用场景

- 调整 UI 布局、页面导航、数据展示
- **不适合**测试扫码功能（`mobile_scanner` 在 Web 上不可用）
- 需要测试扫码、签名等原生功能时改用真机 `flutter run`

## 热重载

服务启动后，在运行终端中：
- 按 `r` — 热重载（秒级，保留状态）
- 按 `R` — 热重启（秒级，重置状态）
- 按 `q` — 退出服务
