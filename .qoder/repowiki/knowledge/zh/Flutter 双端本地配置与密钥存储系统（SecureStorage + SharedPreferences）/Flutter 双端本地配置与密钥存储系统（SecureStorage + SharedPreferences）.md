---
kind: configuration_system
name: Flutter 双端本地配置与密钥存储系统（SecureStorage + SharedPreferences）
category: configuration_system
scope:
    - '**'
source_files:
    - coldwallet-app/lib/services/secure_storage_service.dart
    - coldwallet-app/lib/services/wallet_service.dart
    - coldwallet-watch/lib/services/storage_service.dart
    - coldwallet-watch/lib/services/blockfrost_service.dart
    - coldwallet-watch/lib/services/tx_builder_service.dart
    - coldwallet-watch/lib/screens/settings_screen.dart
---

## 1. 整体方案

本项目为两个独立的 Flutter 应用：`coldwallet-app`（离线冷钱包）和 `coldwallet-watch`（联网观察端）。两者均**没有使用集中式配置文件或环境变量注入框架**，而是通过平台原生持久化 API 在运行时加载/写入配置：
- 冷钱包端使用 `flutter_secure_storage`（底层走 Android Keystore/iOS Keychain），所有敏感数据（助记词、PIN、当前网络、钱包列表）均以 key-value 形式加密落盘。
- 观察端采用**混合策略**：非敏感的用户偏好（钱包列表、当前钱包 ID、启用资产列表）使用 `shared_preferences` 明文存储；敏感凭据（Blockfrost API Key）则存入 `flutter_secure_storage`。
- 网络端点等只读常量直接以 Dart `static const Map` 硬编码在 `BlockfrostEndpoint.baseUrls` 中，不支持运行时切换。

项目未引入 `.env`、`dotenv`、`Platform.environment`、`get_it`、`Provider`、`BlocProvider` 等任何外部配置依赖，属于“轻量级、按服务拆分”的本地配置模式。

## 2. 关键文件与职责

| 文件 | 职责 |
|---|---|
| `coldwallet-app/lib/services/secure_storage_service.dart` | 冷钱包安全存储抽象，定义 `wallet_list`、`wallet_{id}_mnemonic`、`current_wallet_id`、`current_network`、`wallet_pin_hash` 等 key 约定 |
| `coldwallet-app/lib/services/wallet_service.dart` | 业务层聚合 SecureStorageService，暴露多钱包管理、助记词生成/校验、网络设置（mainnet/testnet）、PIN 管理等接口 |
| `coldwallet-watch/lib/services/storage_service.dart` | 观察端统一存储入口：SharedPreferences 负责钱包元数据，FlutterSecureStorage 负责 Blockfrost API Key |
| `coldwallet-watch/lib/services/blockfrost_service.dart` | 网络配置中心：`BlockfrostEndpoint.baseUrls` 固定 mainnet/preprod/preview 三套 Base URL，构造请求头时注入 `project_id` |
| `coldwallet-watch/lib/screens/settings_screen.dart` | 用户可编辑的配置界面：仅允许修改 Blockfrost API Key；网络显示为“Preview 测试网（已固定）” |
| `coldwallet-watch/lib/services/tx_builder_service.dart` | 交易构建时根据传入 `network` 字符串映射到 `NetworkId.mainnet` / `NetworkId.testnet`，是网络配置的下游消费者 |

## 3. 架构与约定

### 3.1 分层模型
```
UI 层 (screens)
  ↓ 调用
业务 Service 层 (wallet_service / tx_builder_service / asset_service …)
  ↓ 委托
存储 Service 层 (secure_storage_service / storage_service)
  ↓ 平台
Android Keystore / iOS Keychain / SharedPreferences
```
每个 Service 持有自己的存储实例（如 `WalletService` 内部 `SecureStorageService _secureStorage = SecureStorageService()`；`TxBuilderService` 依赖注入 `BlockfrostService`），不存在全局单例容器。

### 3.2 配置键命名约定
- 冷钱包端：`wallet_list`、`wallet_{id}_mnemonic`、`current_wallet_id`、`current_network`、`wallet_pin_hash`（见 `SecureStorageService` 注释中的“存储 Key 规划”）。
- 观察端：`watch_wallets`、`current_wallet_id`、`blockfrost_api_key`、`enabled_assets_{walletId}`（前缀拼接）。
- 网络值约定：字符串 `'mainnet'` / `'testnet'`（冷钱包端默认 `'testnet'`；观察端 `getCurrentNetwork()` 固定返回 `'preview'`）。

### 3.3 敏感与非敏感分离
- **冷钱包端**：全部敏感数据（助记词、PIN、钱包列表、当前网络）一律走 `flutter_secure_storage`，因为 App 完全离线，密钥不能离开设备。
- **观察端**：区分对待——钱包元数据用 `SharedPreferences` 明文存储（不影响安全边界），只有 Blockfrost API Key 走安全存储。API Key 通过 Settings 页面输入并保存。

### 3.4 网络配置策略差异
- 冷钱包端：`WalletService.getNetwork()/setNetwork()` 读写 `current_network`，支持 mainnet/testnet 切换，并在 `createWallet` / `deriveAddress` 时据此选择 `NetworkId`。
- 观察端：`BlockfrostEndpoint.baseUrls` 提供三个网络的 Base URL，但 `StorageService.getCurrentNetwork()` 硬编码返回 `'preview'`，且 UI 明确提示“已固定”，因此观察端实际不可由用户切换网络。

## 4. 约束与规则

1. **无全局配置对象**：代码库中未发现类似 `Config`、`AppConfig`、`Environment` 的全局单例，配置通过各 Service 构造函数或静态字段获取。
2. **密钥不落盘明文**：冷钱包端助记词、PIN 必须经 `flutter_secure_storage` 存取；观察端 API Key 同样走安全存储（`storage_service.dart` 注释明确说明）。
3. **网络值域受约束**：网络参数仅在 `'mainnet'` / `'testnet'` / `'preview'` / `'preprod'` 之间取值，超出范围会回退到默认（`BlockfrostService._baseUrl` 对未知 network 回落到 `preview`）。
4. **最大钱包数限制**：冷钱包端 `WalletService.maxWallets = 5`，新增钱包时显式检查上限，违反时抛出 `StateError`。
5. **PIN 暂为明文存储**：`SecureStorageService.savePin` 与 `verifyPin` 目前直接比较字符串，代码中标注 TODO 改为 argon2/PBKDF2 哈希后再比较。
6. **无 .env / 环境变量读取**：搜索 `environment`、`.env`、`dotenv`、`Platform.environment` 均未命中，运行期不读取进程环境变量。
7. **Blockfrost 端点不可变**：Base URL 以 `static const Map` 固化在源码中，不提供运行时覆盖机制。

## 5. 总结

该仓库的“配置系统”本质上是**按服务划分的本地持久化键值存储**，配合少量硬编码常量构成。它没有统一的配置加载器、环境切换机制或 feature flag 体系；配置即“用户设置 + 平台安全存储”。这种设计契合冷钱包“离线、最小依赖”的安全目标，但也意味着扩展新配置项时需要自行新增 key、读写方法与 UI 入口。