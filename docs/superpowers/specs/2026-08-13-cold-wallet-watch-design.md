# Cardano 冷钱包热端（Watch-Only）App 设计规格

> 日期：2026-08-13
> 状态：设计确认，待实施
> 范围：MVP — 只读热钱包 + 手动转账 + 冷签名闭环

---

## 1. 项目概述

开发一个独立的 Flutter Android App，作为 `coldwallet-app`（离线签名端）的配套联网端。该 App **不存储、不输入、不处理任何私钥或助记词**，仅通过只读地址实现：

- 查询链上余额（ADA + 原生代币 + NFT）
- 构建未签名交易
- 通过二维码 / JSON 文本 / 文件导出给冷钱包签名
- 导入签名结果并提交到 Cardano 网络

---

## 2. 技术决策汇总

| 决策项 | 选择 |
|--------|------|
| 产品形态 | 独立 Android App |
| 框架 | Flutter |
| 项目名称 | `coldwallet-watch` |
| 包名 | `com.coldwallet.coldwallet_watch`（待定） |
| 链上数据 | Blockfrost（用户自备 API Key） |
| 交易构建 SDK | `cardano_flutter_sdk` |
| 网络支持 | Mainnet / Preview / Preprod，用户可切换 |
| 通信方式 | 二维码 + JSON 文本 + 文件 |
| 地址管理 | 多个只读地址，支持自定义命名 |
| 资产显示 | ADA + 原生代币 + NFT，但仅显示用户手动开启的资产 |
| dApp 浏览器 / CIP-30 | MVP 不做 |
| 交易历史 | MVP 不做 |

---

## 3. 整体架构

```
┌─────────────────────────────────────────────┐
│           coldwallet-watch                   │
│           （联网热钱包 App）                   │
│                                              │
│  ┌─────────────┐  ┌─────────────────────┐   │
│  │ 只读钱包管理 │  │ 手动转账            │   │
│  │ 地址 + 命名  │  │ 构建 unsigned tx    │   │
│  └──────┬──────┘  └──────────┬──────────┘   │
│         │                    │               │
│         ▼                    ▼               │
│  ┌──────────────────────────────────────┐   │
│  │ Blockfrost Provider                  │   │
│  │ - 查余额 / UTXO                      │   │
│  │ - 提交已签名交易                     │   │
│  └──────────────────────────────────────┘   │
│         │                    │               │
│         ▼                    ▼               │
│  ┌─────────────┐  ┌─────────────────────┐   │
│  │ 导出 QR/JSON/文件 │  │ 导入签名 QR/文件    │   │
│  │ 给冷钱包签名 │  │ 提交上链            │   │
│  └─────────────┘  └─────────────────────┘   │
└─────────────────────────────────────────────┘
              │                    ▲
              │ QR / JSON / 文件   │ QR / JSON / 文件
              ▼                    │
┌─────────────────────────────────────────────┐
│           coldwallet-app                     │
│           （离线签名端）                       │
│  扫码/导入 → 展示 → PIN → 签名 → 导出        │
└─────────────────────────────────────────────┘
```

### 设计原则

1. **无私钥原则**：不存储、不输入、不处理助记词或私钥。
2. **只读地址本地存储**：地址是公开信息，使用普通本地存储（SharedPreferences）。
3. **API Key 安全存储**：Blockfrost Project ID 使用 `flutter_secure_storage` 加密存储。
4. **网络隔离清晰**：热端必须有网络权限；冷端必须完全离线。
5. **复用数据契约**：与 `coldwallet-app` 共用 `ColdExport` / `ColdImport` JSON 格式。

---

## 4. 目录结构

```
coldwallet-watch/
├── lib/
│   ├── main.dart                          → 应用入口
│   ├── app.dart                           → MaterialApp + 路由 + 主题
│   ├── models/
│   │   ├── watch_wallet.dart              → 只读钱包模型
│   │   ├── asset_balance.dart             → 资产余额模型
│   │   ├── cold_export.dart               → 未签名交易导出契约
│   │   └── cold_import.dart               → 已签名交易导入契约
│   ├── services/
│   │   ├── storage_service.dart           → 本地存储（地址、设置、API Key）
│   │   ├── blockfrost_service.dart        → Blockfrost API 封装
│   │   ├── wallet_service.dart            → 地址管理、余额查询
│   │   └── tx_builder_service.dart        → 交易构建
│   ├── screens/
│   │   ├── home_screen.dart               → 钱包列表 + 余额概览
│   │   ├── wallet_detail_screen.dart      → 余额详情 + 资产开关
│   │   ├── add_wallet_screen.dart         → 添加只读地址
│   │   ├── send_screen.dart               → 发起转账
│   │   ├── export_tx_screen.dart          → 导出 QR / JSON / 文件
│   │   ├── import_signed_screen.dart      → 导入签名结果
│   │   └── settings_screen.dart           → 网络切换、API Key
│   └── widgets/
│       ├── qr_display.dart                → 二维码展示
│       ├── qr_scanner.dart                → 二维码扫描
│       ├── asset_list.dart                → 资产列表
│       └── export_options.dart            → 导出方式选择
├── android/
├── pubspec.yaml
└── analysis_options.yaml
```

---

## 5. 核心模型

### WatchWallet

```dart
class WatchWallet {
  final String id;           // UUID
  final String name;         // 用户自定义名称
  final String address;      // Cardano 地址
  final String network;      // mainnet / preview / preprod
  final DateTime createdAt;
}
```

### AssetBalance

```dart
class AssetBalance {
  final String unit;         // "lovelace" 或 policyId + assetNameHex
  final String quantity;
  final String? displayName; // ADA / Token / NFT 名称
  final bool isEnabled;      // 用户是否开启显示
}
```

### ColdExport（与 coldwallet-app 共用）

```json
{
  "version": 1,
  "type": "unsigned-tx",
  "network": "mainnet",
  "txCbor": "...",
  "summary": {
    "fromAddress": "addr1...",
    "toAddress": "addr1...",
    "assets": [
      {"unit": "lovelace", "quantity": "1000000", "displayName": "ADA"}
    ],
    "fee": "168273"
  }
}
```

### ColdImport（与 coldwallet-app 共用）

```json
{
  "version": 1,
  "type": "signed-tx",
  "txCbor": "...",
  "txHash": "..."
}
```

---

## 6. 手动转账数据流

### 6.1 添加只读钱包

1. 用户输入地址和名称。
2. 使用 `cardano_flutter_sdk` 校验地址格式和对应网络。
3. 保存到 `SharedPreferences`。
4. 返回首页显示钱包卡片。

### 6.2 查询余额

1. 用户进入 `WalletDetailScreen`。
2. 调用 `blockfrost_service.getAddressBalance(address, network)`。
3. Blockfrost 返回 UTXO 列表及资产信息。
4. 按 `unit` 聚合余额。
5. 仅展示 `isEnabled == true` 的资产。
6. 提供"管理显示资产"入口，用户可手动开启/隐藏资产。

### 6.3 构建转账交易

1. 用户在 `SendScreen` 输入：
   - 收款地址
   - 转账资产（ADA / 代币 / NFT）
   - 金额
2. `tx_builder_service.buildTransferTx(...)` 执行：
   - 查询 UTXO（Blockfrost）
   - Coin Selection 选择输入
   - 计算手续费
   - 找零给 `fromAddress`
   - 输出 unsigned tx CBOR
3. 包装为 `ColdExport` JSON。

### 6.4 导出给冷钱包

`ColdExport` JSON → `JSON.stringify` 后支持三种导出：

1. **二维码**：生成 QR 码展示在 `ExportTxScreen`。
2. **JSON 文本**：复制到剪贴板，用户可粘贴到聊天工具等。
3. **文件**：保存为 `.json` 文件到手机 Downloads。

### 6.5 导入签名结果并提交

1. 用户在 `ImportSignedScreen` 选择扫码或文件导入。
2. 解析为 `ColdImport` JSON。
3. 调用 `blockfrost_service.submitTx(txCbor)`。
4. 显示 `txHash`，交易已提交。

---

## 7. 依赖列表

```yaml
dependencies:
  flutter:
    sdk: flutter
  cardano_flutter_sdk: ^4.0.1
  cardano_dart_types: ^3.0.0
  http: ^1.2.0
  mobile_scanner: ^3.0.0
  qr_flutter: ^4.1.0
  file_picker: ^12.0.0-beta.7
  path_provider: ^2.1.6
  shared_preferences: ^2.3.0
  flutter_secure_storage: ^9.0.0
```

---

## 8. 安全设计

| 项目 | 处理方式 |
|------|----------|
| 私钥 / 助记词 | 不存储、不输入、不处理 |
| 只读地址 | `SharedPreferences` 普通存储 |
| 钱包名称 | `SharedPreferences` 普通存储 |
| Blockfrost API Key | `flutter_secure_storage` 加密存储 |
| 交易签名 | 不签名，只构建 unsigned tx |
| 提交交易 | 使用导入的 signed tx CBOR，不接触私钥 |
| 网络权限 | 仅用于 Blockfrost 查询和提交 |

---

## 9. 错误处理

| 场景 | 处理 |
|------|------|
| 地址格式错误 | 实时校验，提示"地址格式不正确" |
| 地址网络不匹配 | 提示当前网络与地址网络不一致 |
| 余额不足 | 构建前检查，提示"余额不足" |
| Blockfrost 请求失败 | 重试 1 次，提示网络或 API Key 错误 |
| 收款地址与发送地址相同 | 拦截，提示不能转账给自己 |
| 二维码扫描失败 | 提示"无法识别，请重试或改用文件" |
| 导入签名文件解析失败 | 提示"签名文件格式错误" |
| 提交交易失败 | 显示 Blockfrost 返回的错误信息 |

---

## 10. MVP 范围

### 包含

- [x] 多个只读地址管理（添加、删除、重命名、切换）
- [x] ADA / 原生代币 / NFT 余额查询
- [x] 用户手动开启/隐藏资产
- [x] 手动转账（ADA / 代币 / NFT）
- [x] 导出未签名交易：二维码、JSON 文本、文件
- [x] 导入签名结果：二维码、文件
- [x] 提交已签名交易到 Blockfrost
- [x] 网络切换（Mainnet / Preview / Preprod）
- [x] Blockfrost API Key 设置

### 不包含（后续迭代）

- [ ] dApp 浏览器 / CIP-30
- [ ] 交易历史
- [ ] 质押注册 / 委托 / 领取奖励
- [ ] 治理投票
- [ ] 智能合约交互
- [ ] NFT 元数据展示
- [ ] 多语言
- [ ] 生物识别 / PIN 锁（因无敏感数据）

---

## 11. 开发顺序

1. 创建 Flutter 项目 `coldwallet-watch`。
2. 配置 Android 包名、网络权限、Gradle 镜像。
3. 实现本地存储（地址、设置、API Key）。
4. 实现 Blockfrost 服务（余额、UTXO、提交交易）。
5. 实现地址管理和首页。
6. 实现余额展示和资产开关。
7. 实现手动转账和交易构建。
8. 实现导出（QR / JSON / 文件）。
9. 实现签名导入和提交。
10. 实现网络切换和设置页。
11. 与 `coldwallet-app` 进行 QR / 文件交换端到端测试。

---

## 12. 与 coldwallet-app 的接口契约

热端和冷端通过以下 JSON 契约交互：

- 热端 → 冷端：`ColdExport`（`type: "unsigned-tx"`）
- 冷端 → 热端：`ColdImport`（`type: "signed-tx"`）

传输方式：

- 二维码
- JSON 文本复制粘贴
- `.json` 文件导入导出

两种设备之间的数据交换**只包含 CBOR 交易体**，不包含任何私钥或助记词。
