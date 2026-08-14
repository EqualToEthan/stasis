# Cardano 冷钱包设计规格

> 日期：2026-08-10
> 更新：2026-08-12（App 端改为 Flutter 架构）
> 状态：设计确认，待实施
> MVP 范围：第一阶段 — 基础冷转账

---

## 1. 项目概述

开发一个 Cardano 冷钱包系统，包含浏览器插件（联网端）和手机 App（离线签名端）。核心安全模型：插件不存储私钥/助记词，用户通过公钥地址登录查看余额，交易通过 QR 码或文件在联网设备和离线设备之间传递。

## 2. 技术决策汇总

| 决策项 | 选择 |
|--------|------|
| MVP 范围 | 严格第一阶段：ADA 转账 + 原生代币转账 |
| 插件框架 | React + TypeScript |
| 插件构建 | Plasmo (Manifest V3) |
| 目标浏览器 | 仅 Chrome |
| 离线签名端 | Flutter (仅 Android) |
| App 端链上 SDK | cardano_flutter_sdk (Dart，CIP-1852 BIP32-Ed25519) |
| App 端安全存储 | flutter_secure_storage (Android Keystore) |
| 通信方式 | QR 码 + 文件导入导出（双通道） |
| 链上 SDK | Lucid Evolution (@lucid-evolution/lucid) |
| 数据 Provider | Blockfrost |
| 测试网络 | preview |
| 代码结构 | 三个独立仓库 |
| 大交易处理 | MVP 不涉及（简单转账 < 3KB，单 QR 码可承载） |

## 3. 整体架构

三个独立仓库，通过 CBOR/JSON 数据格式作为接口契约：

```
┌──────────────────┐         ┌──────────────────┐
│  coldwallet-ext  │         │  coldwallet-app  │
│  (Chrome 插件)    │         │  (Flutter/Android)│
│  React + TS       │         │  Dart            │
│                  │         │                  │
│  - 地址登录       │         │  - 扫码/导入       │
│  - 余额查询       │         │  - 交易详情展示    │
│  - 构建交易       │         │  - 私钥签名        │
│  - QR/文件导出    │◄────────►│  - QR/文件导出    │
│  - 扫码/导入签名  │  JSON   │                  │
│  - 提交交易       │  +CBOR  │                  │
└────────┬─────────┘         └──────────────────┘
         │
         │ imports
         ▼
┌──────────────────┐
│  coldwallet-core │  (插件端独立使用的 TS 包)
│  (npm 包)         │
│                  │
│  - tx-builder    │  交易构建 (Lucid Evolution)
│  - cbor-utils    │  CBOR 编解码
│  - signer        │  签名逻辑
│  - types         │  共享类型定义
│  - provider      │  Blockfrost 封装
└──────────────────┘
```

**开发顺序（方案 A：核心优先）**：

1. `coldwallet-core` — 纯逻辑包，供插件端使用（App 端使用 Dart SDK 独立实现）
2. `coldwallet-ext` — Plasmo 插件，集成 core 的交易构建逻辑
3. `coldwallet-app` — Flutter App，使用 `cardano_flutter_sdk` 独立实现签名逻辑

**仓库间依赖**：
- 插件与 core：MVP 阶段 core 不发布 npm，使用 `npm pack` 本地安装或 `file:` 协议引用
- App：独立 Flutter 项目，不依赖 core TS 包，通过 `ColdExport`/`ColdImport` JSON 契约与插件端交互

## 4. coldwallet-core 核心库

### 目录结构

```
coldwallet-core/
├── src/
│   ├── provider/
│   │   └── blockfrost.ts       → getUtxos(), getBalance(), submitTx()
│   ├── tx-builder/
│   │   ├── transfer.ts         → 构建 ADA 转账 unsigned tx
│   │   ├── token-transfer.ts   → 构建原生代币转账 unsigned tx
│   │   └── common.ts           → fee 计算、UTXO 选择辅助
│   ├── signer/
│   │   ├── sign.ts             → 用私钥签名 unsigned tx
│   │   └── assemble.ts         → 组装 signed tx (unsigned + witnesses)
│   ├── cbor/
│   │   ├── encode.ts           → unsigned tx → CBOR hex
│   │   └── decode.ts           → CBOR → 解析交易详情
│   ├── wallet/
│   │   ├── address.ts          → 地址校验、地址信息解析
│   │   ├── key.ts              → 公钥/私钥操作（仅 App 端使用）
│   │   └── dice.ts             → 骰子熵收集 + SHA-256 哈希 → BIP39 助记词
│   └── types/
│       ├── transaction.ts      → UnsignedTxPayload, SignedTxPayload
│       └── wallet.ts           → WalletInfo, AddressInfo
├── package.json
└── tsconfig.json
```

### 关键接口

```typescript
// 插件端导出给离线设备的数据
interface UnsignedTxPayload {
  txCbor: string;        // 未签名交易的 CBOR hex
  metadata: {
    type: 'ada-transfer' | 'token-transfer';
    fromAddress: string;
    toAddress: string;
    amount: string;      // lovelace 或 token amount
    fee: string;
    network: 'preview' | 'preprod' | 'mainnet';
  };
}

// 离线设备签名后导出的数据
interface SignedTxPayload {
  txCbor: string;        // 已签名交易的 CBOR hex
  txHash: string;        // 交易哈希
}
```

### 核心流程

1. 插件端调用 `tx-builder` 构建交易 → 得到 `Tx` 对象
2. core 用 `cbor/encode` 把 `Tx` 序列化为 `UnsignedTxPayload`
3. 导出为 QR 码或文件
4. App 端用 `cbor/decode` 解析展示交易详情
5. 用户确认 → core 用 `signer/sign` 签名
6. core 用 `cbor/encode` 输出 `SignedTxPayload`
7. 插件端用 `provider` 提交到链上

## 5. coldwallet-ext 浏览器插件

### 目录结构

```
coldwallet-ext/
├── src/
│   ├── popup/
│   │   ├── index.tsx              → Popup 入口
│   │   ├── pages/
│   │   │   ├── Login.tsx             → 输入地址/公钥登录（只读）
│   │   │   ├── Dashboard.tsx         → 余额展示、收款地址
│   │   │   ├── Send.tsx              → 发起转账（输入地址+金额）
│   │   │   ├── ExportTx.tsx          → 展示 QR 码 / 下载 .cbor 文件
│   │   │   ├── ImportSigned.tsx      → 扫码读取 / 导入签名文件
│   │   │   └── TxHistory.tsx         → 交易历史列表
│   │   └── components/
│   │       ├── QRDisplay.tsx         → QR 码生成展示
│   │       ├── QRScanner.tsx         → 摄像头扫码读取
│   │       └── AddressInput.tsx      → 地址输入+校验组件
│   ├── background/
│   │   └── index.ts                → Service Worker，消息处理、Blockfrost 调用
│   ├── lib/
│   │   ├── provider.ts             → Blockfrost 实例管理
│   │   ├── tx-flow.ts              → 串联 core 的交易流程
│   │   └── storage.ts              → Chrome storage（缓存地址、设置）
│   └── types/
│       └── index.ts
├── package.json                    → 依赖 coldwallet-core
└── tsconfig.json
```

### 页面流程

```
Login → 输入 Cardano 地址
  │
  ▼
Dashboard → 显示余额 + 收款地址 + 快捷操作
  │
  ├──► Send → 输入收款地址 + 金额 → 构建 unsigned tx
  │         │
  │         ▼
  │    ExportTx → 展示 QR 码 或 下载 .cbor 文件
  │         │
  │         │   (用户去手机 App 签名)
  │         ▼
  │    ImportSigned → 摄像头扫码 或 导入 .cbor 文件
  │         │
  │         ▼
  │    提交交易 → 显示 TxHash ✓
  │
  └──► TxHistory → 查看历史交易记录
```

### 关键技术点

- **只读登录**：用户粘贴地址即可，不需要助记词/私钥
- **QR 码生成**：`qrcode` 库把 ColdExport JSON 编码为 QR
- **QR 码扫描**：`jsQR` + 浏览器 `getUserMedia` 摄像头 API
- **文件导出**：`Blob` + `URL.createObjectURL` 下载 `.cbor` 文件
- **文件导入**：`<input type="file">` 读取 `.cbor` 文件
- **Chrome Storage**：缓存最近使用的地址、Blockfrost API Key

## 6. coldwallet-app 离线签名 App

> 2026-08-12 更新：从 React Native (Expo) 迁移到 Flutter，仅支持 Android 平台。

### 框架选型理由

选择 Flutter 替代 React Native (Expo) 基于以下安全考量：

| 考量维度 | React Native (Expo) | Flutter |
|----------|---------------------|--------|
| 私钥存储 | JS 堆内存中可被读取，Bridge 暴露风险 | Dart FFI 调用原生代码，私钥不进入 JS 堆 |
| CIP-1852 派生 | Lucid Evolution 依赖 WASM，RN 环境不兼容 | cardano_flutter_sdk 原生 Dart 实现 |
| APK 构建 | 云端构建（安全不可审计） | 本地 `flutter build apk` 完全透明 |
| 安全存储 | expo-secure-store | flutter_secure_storage + Android Keystore |
| 平台覆盖 | iOS + Android | 仅 Android（冷钱包 MVP） |

### 目录结构

```
coldwallet-app/
├── lib/
│   ├── main.dart                          → 应用入口 + MaterialApp 路由
│   ├── models/
│   │   ├── cold_export.dart               → ColdExport / TxSummary / AssetAmount
│   │   └── cold_import.dart               → ColdImport 已签名交易模型
│   ├── services/
│   │   ├── secure_storage_service.dart    → flutter_secure_storage 封装
│   │   ├── wallet_service.dart            → 助记词生成/校验/存储、地址派生
│   │   └── transaction_service.dart       → 交易解析、签名、CBOR 组装
│   └── screens/
│       ├── home_screen.dart               → 首页：扫码 / 导入 / 钱包管理入口
│       ├── wallet_setup_screen.dart       → 钱包初始化：生成 / 导入助记词 + 设 PIN
│       ├── scan_tx_screen.dart            → 摄像头扫描插件端 QR 码
│       ├── tx_detail_screen.dart          → 展示交易详情
│       ├── confirm_sign_screen.dart       → 确认签名（PIN 验证）
│       └── export_signed_screen.dart      → 展示签名后 QR 码 / 复制 / 分享文件
├── test/
│   └── widget_test.dart
├── android/
├── pubspec.yaml
└── analysis_options.yaml
```

### 使用流程

```
HomeScreen
  │
  ├──► ScanTxScreen → 摄像头扫描插件端 QR 码
  │         │
  │         ▼
  │    TxDetailScreen → 解析并展示交易详情
  │         │         (发送方、接收方、金额、手续费、网络)
  │         ▼
  │    ConfirmSignScreen → 输入 6 位 PIN → verifyPin()
  │         │
  │         ▼
  │    TransactionService.signTransaction()
  │    （WalletFactory → CardanoWallet → signTransaction）
  │         │
  │         ▼
  │    ExportSignedScreen → 展示签名后 QR 码 / 复制 / 分享文件
  │
  ├──► 文件导入（预留，MVP 仅扫码）
  │
  └──► WalletSetupScreen → 生成 / 导入助记词、设置 PIN、查看地址、重置钱包
```

### 安全设计

| 层级 | 措施 |
|------|------|
| 私钥存储 | Android Keystore（flutter_secure_storage，EncryptedSharedPreferences） |
| 访问控制 | 签名前需 6 位数字 PIN 验证 |
| 网络隔离 | App 无任何网络请求代码，不引入 HTTP 库（如 dio、http） |
| 助记词导入 | 仅支持手动输入 |
| 助记词生成 | cardano_flutter_sdk `WalletFactory.generateNewMnemonic` (24 词) |
| 密钥派生 | CIP-1852 BIP32-Ed25519 (cardano_flutter_sdk) |
| 签名 | cardano_flutter_sdk `CardanoWallet.signTransaction` |
| PIN 存储 | 保存 PIN 哈希（当前为占位，后续引入 argon2/PBKDF2） |
| 内存清理 | Dart GC 自动回收，签名后不保留私钥引用 |

### 关键技术选型

| 功能 | 包 | 说明 |
|------|-----|------|
| Flutter 框架 | flutter | Material 3 |
| 链上 SDK | cardano_flutter_sdk | CIP-1852、签名、地址派生 |
| 类型定义 | cardano_dart_types | CBOR、Transaction、Address 等 |
| 助记词 | bip39_plus | BIP-39 验证 |
| 哈希 | pointycastle | blake2b_256 交易哈希 |
| 十六进制 | hex | hex 编解码 |
| 安全存储 | flutter_secure_storage | Android Keystore |
| 摄像头扫码 | mobile_scanner | 二维码扫描 |
| 二维码生成 | qr_flutter | QR 码展示 |
| 文件分享 | share_plus + path_provider | 导出签名文件 |
| 测试 | flutter_test | 基础 widget 测试 |

## 7. 设备间数据交换格式

### 格式选择：JSON 包装 + CBOR 交易体

外层用 JSON 传递元信息，交易本体为 CBOR hex 字符串。

```typescript
// 插件 → 离线设备（未签名交易）
interface ColdExport {
  version: 1;
  type: "unsigned-tx";
  network: "preview";

  txCbor: string;                      // unsigned tx 的 CBOR hex

  summary: {
    fromAddress: string;
    toAddress: string;
    assets: AssetAmount[];
    fee: string;                       // lovelace
  };
}

interface AssetAmount {
  unit: string;                        // "lovelace" 或 policyId.assetName hex
  quantity: string;
  displayName?: string;                // 如 "ADA"、"MyNFT"
}

// 离线设备 → 插件（已签名交易）
interface ColdImport {
  version: 1;
  type: "signed-tx";

  txCbor: string;                      // signed tx 的 CBOR hex
  txHash: string;                      // 交易哈希
}
```

### 编码流程

```
插件端：ColdExport → JSON.stringify → QR 码
App 端：扫描 QR → JSON.parse → ColdExport → 展示 summary → 签名
App 端：ColdImport → JSON.stringify → QR 码
插件端：扫描 QR → JSON.parse → ColdImport → 提交
```

### 容量预估

- ColdExport JSON ≈ 400-800 bytes → 单 QR 码轻松承载（QR 上限 ~3KB）
- ColdImport JSON ≈ 300-500 bytes → 单 QR 码轻松承载

## 8. 不在 MVP 范围内（后续迭代）

- CIP-30 dApp 连接接口
- 质押注册/委托/领取奖励
- 治理投票 (CIP-95 / CIP-1694)
- 智能合约交互
- Animated QR 大交易分帧
- 多账户/多地址支持
- 硬件钱包集成
- Firefox / 多浏览器支持
- NFT 元数据展示
