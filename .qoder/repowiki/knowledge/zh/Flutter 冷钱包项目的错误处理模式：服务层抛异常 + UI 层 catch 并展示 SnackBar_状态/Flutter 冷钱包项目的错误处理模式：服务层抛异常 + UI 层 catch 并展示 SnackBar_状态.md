---
kind: error_handling
name: Flutter 冷钱包项目的错误处理模式：服务层抛异常 + UI 层 catch 并展示 SnackBar/状态
category: error_handling
scope:
    - '**'
source_files:
    - coldwallet-app/lib/services/wallet_service.dart
    - coldwallet-app/lib/services/transaction_service.dart
    - coldwallet-watch/lib/services/blockfrost_service.dart
    - coldwallet-watch/lib/services/tx_builder_service.dart
    - coldwallet-app/lib/screens/home_screen.dart
    - coldwallet-app/lib/screens/wallet_setup_screen.dart
    - coldwallet-app/lib/screens/confirm_sign_screen.dart
    - coldwallet-app/lib/screens/dice_entropy_screen.dart
    - coldwallet-app/lib/screens/scan_tx_screen.dart
    - coldwallet-watch/lib/screens/home_screen.dart
    - coldwallet-watch/lib/screens/add_wallet_screen.dart
    - coldwallet-watch/lib/screens/export_tx_screen.dart
    - coldwallet-watch/lib/screens/import_signed_screen.dart
---

## 1. 整体方案

本项目为 Flutter（coldwallet-app 冷签名端 + coldwallet-watch 联网观察端）+ 设计文档的仓库，**没有统一的错误类型库、错误码枚举或全局中间件**。错误处理采用“服务层抛出 Dart 内置异常 + UI 层 try/catch 捕获并以 SnackBar / 页面状态展示”的模式。

- 业务/网络/解析等“可预期失败”路径在 Service 中 `throw` 标准异常（`Exception`、`ArgumentError`、`StateError`、`UnsupportedError`），由调用方捕获。
- UI 层（`screens/*.dart`）用 `try { ... } catch (e) { ... }` 包裹异步操作，将 `e.toString()` 写入本地 `_error` 状态或通过 `ScaffoldMessenger.of(context).showSnackBar(...)` 弹出提示。
- 未发现 `panic/recover`（Dart 无 panic）、未定义自定义 `AppException`/错误码、未使用 `rxdart`/`bloc` 等统一错误流。

## 2. 关键文件与位置

| 层级 | 文件 | 作用 |
|---|---|---|
| 冷钱包 App 服务 | `coldwallet-app/lib/services/wallet_service.dart` | 助记词校验、钱包数量上限等抛 `ArgumentError` / `StateError` |
| 冷钱包 App 服务 | `coldwallet-app/lib/services/transaction_service.dart` | 未初始化时抛 `Exception('当前钱包未初始化或助记词丢失')` |
| 观察端服务 | `coldwallet-watch/lib/services/blockfrost_service.dart` | HTTP 非 200 时抛 `Exception('Blockfrost error: ...')`；提交失败抛 `Exception('Submit failed: ...')` |
| 观察端服务 | `coldwallet-watch/lib/services/tx_builder_service.dart` | 不支持资产类型抛 `UnsupportedError`；UTxO 为空/余额不足/手续费不收敛抛 `Exception` |
| 冷钱包 App UI | `coldwallet-app/lib/screens/home_screen.dart`、`confirm_sign_screen.dart`、`dice_entropy_screen.dart`、`scan_tx_screen.dart`、`wallet_setup_screen.dart` | `catch (e)` → `SnackBar(content: Text('... $e'), backgroundColor: Colors.red)` |
| 观察端 UI | `coldwallet-watch/lib/screens/home_screen.dart`、`add_wallet_screen.dart`、`export_tx_screen.dart`、`import_signed_screen.dart`、`send_screen.dart` | `catch (e)` → 写入 `_error` 状态或 `SnackBar` |

## 3. 架构与约定

### 3.1 服务层：按语义选择异常类型
- **参数非法**：`wallet_service.dart` 对骰子熵长度检查抛 `ArgumentError('需要恰好 256 个骰子结果')`。
- **状态非法**：`wallet_service.dart` 添加钱包超过 `maxWallets=5` 时抛 `StateError('钱包数量已达上限（$maxWallets）')`。
- **能力受限**：`tx_builder_service.dart` 对非 ADA 转账抛 `UnsupportedError('MVP 仅支持 ADA（lovelace）转账')`。
- **资源缺失/业务失败**：`transaction_service.dart` 助记词丢失抛 `Exception('当前钱包未初始化或助记词丢失')`；`blockfrost_service.dart` 网络响应非 200 抛 `Exception('Blockfrost error: ${statusCode} ${body}')`；`tx_builder_service.dart` UTxO 为空/余额不足/手续费不收敛均抛 `Exception('...')`。

### 3.2 UI 层：就近捕获并反馈
- 冷钱包 App 的 Screen 普遍采用 `try { ... } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('... $e'), backgroundColor: Colors.red)); }` 的写法，错误以红色背景 SnackBar 呈现。
- 观察端 `home_screen.dart` 在 `_load` / `_loadBalances` 中 `catch (e)` 后设置 `_error = e.toString()`，再由 `_buildBody` 渲染 `_buildError(_error!)` 视图。
- 成功类提示也用 `SnackBar`（如“已复制交易哈希”、“地址已复制”），但错误一律带 `Colors.red` 背景。

### 3.3 无全局错误传播机制
- 未发现 `main.dart` 中的 `FlutterError.onError` 或 `runZonedGuarded` 全局捕获。
- 未发现统一的 `Result<T, E>` 或 `Either` 类型；所有异步方法直接 `Future<T>` 并在失败时抛异常。
- 不存在错误码常量文件或错误分类枚举。

## 4. 约定与约束

| 规则 | 证据来源 | 说明 |
|---|---|---|
| 服务层对非法输入/状态/资源缺失直接 `throw` 标准 Dart 异常 | `wallet_service.dart`、`transaction_service.dart`、`blockfrost_service.dart`、`tx_builder_service.dart` | 异常消息包含人类可读原因，便于 UI 直接显示 |
| UI 层必须用 `try/catch` 包裹异步服务调用 | 各 `screens/*.dart` 中大量 `catch (e)` 模式 | 避免未捕获异常导致崩溃 |
| 用户可见的错误通过 `SnackBar` 或页面 `_error` 状态展示 | `home_screen.dart`、`wallet_setup_screen.dart` 等 | 错误信息来自 `e.toString()`，未做二次翻译 |
| 网络错误统一包装为 `Exception`，保留原始 status code 与 body | `blockfrost_service.dart` | 便于调试 Blockfrost API 问题 |
| MVP 能力限制用 `UnsupportedError` 显式表达 | `tx_builder_service.dart` | 明确区分“暂不支持”和“运行时错误” |
| 未定义自定义异常类型或错误码体系 | 全仓搜索未见 `class *Exception extends Exception` | 依赖 Dart 内置异常族 |
| 未使用 `rethrow` 或全局错误处理器 | 全仓搜索未见 `rethrow`、`FlutterError.onError`、`runZonedGuarded` | 错误在调用栈就近消费 |

## 5. 总结

该仓库的错误处理是**轻量且分散的**：Service 层按语义抛出 `ArgumentError` / `StateError` / `UnsupportedError` / `Exception`，UI 层用 `try/catch` 捕获并以 `SnackBar` 或页面状态展示。没有统一的错误类型、错误码、全局捕获或中间件。这种模式适合 MVP 阶段的冷钱包项目，但在多模块复用、错误分类和用户友好化方面仍有扩展空间。