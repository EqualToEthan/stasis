# 多链冷钱包扩展设计

本文档描述在现有 Cardano 冷钱包 (coldwallet-app) 中加入多链支持的架构设计，覆盖 Ethereum、BSC、Arbitrum、Polygon、Base 等 EVM 链，以及 Bitcoin。

## 概述

### 目标

将 coldwallet-app 从单一 Cardano 冷钱包升级为多链冷钱包，支持：

- **Cardano**（现有，preview testnet）
- **EVM 兼容链**：Ethereum Sepolia、BSC Testnet、Arbitrum Sepolia、Polygon Amoy、Base Sepolia（可扩展）
- **Bitcoin**（testnet4，支持 Legacy / SegWit / Taproot 地址格式）

冷钱包端职责不变：**助记词管理 + 多链地址派生 + 离线签名**。交易构建、余额查询等由联网端（观察钱包）负责。

### 核心决策

| 决策点 | 选择 |
|--------|------|
| 钱包与链的关系 | 同一助记词派生所有链的地址（BIP-44 多币种路径） |
| 架构模式 | 链适配器模式（ChainAdapter 接口 + 每链族一个实现） |
| 通信协议 | 三套独立协议（Cardano / EVM / Bitcoin） |
| EVM 链配置 | 内置链配置表，新增链只需加配置项 |
| 网络策略 | 所有链固定为各自测试网，不可切换 |

## 链支持矩阵

| 链族 | 链 | 网络 | chainId | 密钥曲线 | 派生路径 | 地址格式 | 哈希算法 |
|------|-----|------|---------|---------|---------|---------|---------|
| cardano | Cardano | preview | `cardano-preview` | Ed25519 | m/1852'/1815'/0'/0/0 | bech32 | blake2b_256 |
| evm | Ethereum | Sepolia | `evm-11155111` | secp256k1 | m/44'/60'/0'/0/0 | 0x hex | keccak256 |
| evm | BSC | Testnet | `evm-97` | secp256k1 | m/44'/60'/0'/0/0 | 0x hex | keccak256 |
| evm | Arbitrum | Sepolia | `evm-421614` | secp256k1 | m/44'/60'/0'/0/0 | 0x hex | keccak256 |
| evm | Polygon | Amoy | `evm-80002` | secp256k1 | m/44'/60'/0'/0/0 | 0x hex | keccak256 |
| evm | Base | Sepolia | `evm-84532` | secp256k1 | m/44'/60'/0'/0/0 | 0x hex | keccak256 |
| bitcoin | Bitcoin | testnet4 | `bitcoin-testnet4` | secp256k1 | m/84'/1'/0'/0/0 (SegWit testnet) | bech32/base58/bech32m | double SHA-256 |

> 所有 EVM 链共享同一个 secp256k1 密钥和地址，仅 chainId 不同。

## 架构设计

### 整体架构

```
┌──────────────────────────────────────────────────┐
│                  UI 层 (Screens)                  │
│  HomeScreen → ScanTxScreen → ConfirmSignScreen   │
├──────────────────────────────────────────────────┤
│               ChainRegistry                       │
│  根据 chainId 返回 ChainConfig + ChainAdapter     │
├──────────────┬───────────────────────────────────┤
│ ChainAdapter │  (抽象接口)                        │
│ ├ deriveAddress(mnemonic, chainConfig)           │
│ ├ signTransaction(mnemonic, coldExport, config)  │
│ └ parseExport(jsonString)                        │
├──────────────┼──────────────────┬────────────────┤
│ CardanoAdapter│  EvmAdapter     │ BitcoinAdapter │
│ (Ed25519 +   │ (secp256k1 +    │ (secp256k1 +   │
│  CIP-1852 +  │  keccak256 +    │  BIP-84/44 +  │
│  CBOR)       │  EIP-155 + RLP) │  SegWit/等)    │
└──────────────┴──────────────────┴────────────────┘
```

### ChainAdapter 接口

```dart
/// 链适配器抽象接口
///
/// 每条链族（Cardano / EVM / Bitcoin）提供一个实现，
/// 封装地址派生、交易解析和离线签名的链特有逻辑。
abstract class ChainAdapter {
  /// 链族标识，如 "cardano"、"evm"、"bitcoin"
  String get chainFamily;

  /// 从助记词派生指定链的地址
  ///
  /// [mnemonic] BIP-39 助记词（12 或 24 词）
  /// [config] 目标链的配置信息
  /// 返回链特定格式的地址字符串
  Future<String> deriveAddress(String mnemonic, ChainConfig config);

  /// 解析未签名交易的 JSON 字符串
  ///
  /// [jsonString] 链特有的 ColdExport JSON
  /// 返回链特有的 Export 模型对象
  dynamic parseExport(String jsonString);

  /// 签名交易
  ///
  /// [mnemonic] 当前钱包的助记词
  /// [coldExport] parseExport() 返回的对象
  /// [config] 链配置
  /// 返回 SignResult（包含已签名交易 hex 和交易哈希）
  Future<SignResult> signTransaction(
    String mnemonic,
    dynamic coldExport,
    ChainConfig config,
  );
}
```

### ChainConfig 模型

```dart
/// 链配置
///
/// 描述一条链的基本信息，供 ChainAdapter 使用。
/// 所有配置在 ChainRegistry 中静态定义，不可运行时修改。
class ChainConfig {
  /// 唯一标识，如 "cardano-preview"、"evm-11155111"、"bitcoin-testnet4"
  final String chainId;

  /// 链族标识："cardano"、"evm"、"bitcoin"
  final String chainFamily;

  /// 显示名称，如 "Cardano Preview"、"Ethereum Sepolia"
  final String name;

  /// 网络标识，如 "preview"、"sepolia"、"testnet4"
  final String network;

  /// EVM 链专用链 ID（如 11155111、97、421614），非 EVM 链为 null
  final int? evmChainId;

  const ChainConfig({
    required this.chainId,
    required this.chainFamily,
    required this.name,
    required this.network,
    this.evmChainId,
  });
}
```

### SignResult 模型

```dart
/// 签名结果
///
/// 所有链的签名统一返回此结构，包含已签名交易的 hex 编码和交易哈希。
class SignResult {
  /// 已签名交易的 hex 编码（CBOR / RLP / Bitcoin 序列化）
  final String signedTxHex;

  /// 交易哈希 hex
  final String txHash;

  /// 协议版本号
  final int version;

  const SignResult({
    required this.signedTxHex,
    required this.txHash,
    this.version = 1,
  });
}
```

### ChainRegistry 链注册中心

```dart
/// 链注册中心
///
/// 管理所有支持的链配置，提供适配器实例查找。
/// 新增 EVM 链只需在 _configs 中添加一行 ChainConfig。
class ChainRegistry {
  static const Map<String, ChainConfig> _configs = {
    // Cardano
    'cardano-preview': ChainConfig(
      chainId: 'cardano-preview',
      chainFamily: 'cardano',
      name: 'Cardano Preview',
      network: 'preview',
    ),
    // EVM
    'evm-11155111': ChainConfig(
      chainId: 'evm-11155111',
      chainFamily: 'evm',
      name: 'Ethereum Sepolia',
      network: 'sepolia',
      evmChainId: 11155111,
    ),
    'evm-97': ChainConfig(
      chainId: 'evm-97',
      chainFamily: 'evm',
      name: 'BSC Testnet',
      network: 'testnet',
      evmChainId: 97,
    ),
    'evm-421614': ChainConfig(
      chainId: 'evm-421614',
      chainFamily: 'evm',
      name: 'Arbitrum Sepolia',
      network: 'sepolia',
      evmChainId: 421614,
    ),
    'evm-80002': ChainConfig(
      chainId: 'evm-80002',
      chainFamily: 'evm',
      name: 'Polygon Amoy',
      network: 'amoy',
      evmChainId: 80002,
    ),
    'evm-84532': ChainConfig(
      chainId: 'evm-84532',
      chainFamily: 'evm',
      name: 'Base Sepolia',
      network: 'sepolia',
      evmChainId: 84532,
    ),
    // Bitcoin
    'bitcoin-testnet4': ChainConfig(
      chainId: 'bitcoin-testnet4',
      chainFamily: 'bitcoin',
      name: 'Bitcoin testnet4',
      network: 'testnet4',
    ),
  };

  /// 根据链族获取适配器实例
  static ChainAdapter adapterFor(String chainFamily) {
    switch (chainFamily) {
      case 'cardano':
        return CardanoAdapter();
      case 'evm':
        return EvmAdapter();
      case 'bitcoin':
        return BitcoinAdapter();
      default:
        throw UnsupportedError('不支持的链族: $chainFamily');
    }
  }

  /// 根据 chainId 获取链配置
  static ChainConfig? getConfig(String chainId) => _configs[chainId];

  /// 获取所有链配置
  static List<ChainConfig> allConfigs() => _configs.values.toList();

  /// 获取指定链族的所有配置
  static List<ChainConfig> configsForFamily(String family) =>
      _configs.values.where((c) => c.chainFamily == family).toList();
}
```

## 适配器实现

### CardanoAdapter

封装现有 `WalletService` 和 `TransactionService` 中的 Cardano 逻辑：

- **地址派生**：`cardano_flutter_sdk` 的 `WalletFactory.fromMnemonic()` + CIP-1852 路径 `m/1852'/1815'/0'/0/0`
- **交易签名**：CBOR 反序列化 → Ed25519 见证签名 → blake2b_256 哈希
- **协议解析**：现有 `ColdExport.fromJson()`

### EvmAdapter

所有 EVM 链共享一个适配器，通过 `ChainConfig.evmChainId` 区分：

- **地址派生**：
  1. BIP-39 助记词 → 64 字节 seed
  2. BIP-32 派生路径 `m/44'/60'/0'/0/0` → secp256k1 私钥
  3. 取公钥（未压缩 65 字节）→ keccak256 → 取后 20 字节 → `0x` 前缀
- **交易签名**：
  1. RLP 解码 `rawTxHex` 获取未签名 EIP-1559 交易
  2. 用 secp256k1 私钥 + `chainId`（EIP-155）签名
  3. keccak256 计算交易哈希
  4. RLP 编码已签名交易
- **协议解析**：`EthColdExport.fromJson()`

### BitcoinAdapter

- **地址派生**（根据配置选择，testnet coin type = 1）：
  - P2PKH (Legacy)：`m/44'/1'/0'/0/0` → Base58Check 编码
  - P2WPKH (SegWit)：`m/84'/1'/0'/0/0` → bech32 编码 (`tb1q...`)
  - P2TR (Taproot)：`m/86'/1'/0'/0/0` → bech32m 编码 (`tb1p...`)
- **交易签名**：
  1. 解析未签名交易序列化数据
  2. 根据地址类型选择签名方式（Legacy SIGHASH_ALL / SegWit BIP-143 / Taproot BIP-341）
  3. ECDSA 签名（secp256k1）
  4. double SHA-256 计算交易哈希
- **协议解析**：`BtcColdExport.fromJson()`

## 通信协议

### EthColdExport（EVM 链，联网端 → 冷端）

```json
{
  "version": 1,
  "type": "unsigned-tx",
  "chainId": "evm-11155111",
  "rawTxHex": "<RLP 编码的未签名 EIP-1559 交易 hex>",
  "summary": {
    "fromAddress": "0x1234...",
    "toAddress": "0x5678...",
    "value": "1000000000000000000",
    "fee": "21000000000000",
    "nonce": 42
  }
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `version` | `int` | 是 | 协议版本号，当前为 `1` |
| `type` | `String` | 是 | 固定为 `"unsigned-tx"` |
| `chainId` | `String` | 是 | ChainRegistry 中的 chainId |
| `rawTxHex` | `String` | 是 | RLP 编码的未签名交易 hex |
| `summary` | `EvmTxSummary` | 是 | 交易摘要 |

### EvmTxSummary

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `fromAddress` | `String` | 是 | 发送方 0x 地址 |
| `toAddress` | `String` | 是 | 接收方 0x 地址 |
| `value` | `String` | 是 | 转账金额（wei，字符串） |
| `fee` | `String` | 是 | Gas 费用（wei，字符串） |
| `nonce` | `int` | 是 | 交易 nonce |

### EthColdImport（EVM 链，冷端 → 联网端）

```json
{
  "version": 1,
  "type": "signed-tx",
  "rawTxHex": "<RLP 编码的已签名交易 hex>",
  "txHash": "0xabcdef..."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `version` | `int` | 是 | 协议版本号 |
| `type` | `String` | 是 | 固定为 `"signed-tx"` |
| `rawTxHex` | `String` | 是 | RLP 编码的已签名交易 hex |
| `txHash` | `String` | 是 | keccak256 交易哈希 |

### BtcColdExport（Bitcoin，联网端 → 冷端）

```json
{
  "version": 1,
  "type": "unsigned-tx",
  "chainId": "bitcoin-testnet4",
  "rawTxHex": "<未签名交易的序列化 hex>",
  "addressType": "p2wpkh",
  "summary": {
    "inputs": [
      { "txHash": "abc...", "index": 0, "value": "50000" }
    ],
    "outputs": [
      { "address": "tb1q...", "value": "40000" }
    ],
    "fee": "1000"
  }
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `version` | `int` | 是 | 协议版本号 |
| `type` | `String` | 是 | 固定为 `"unsigned-tx"` |
| `chainId` | `String` | 是 | ChainRegistry 中的 chainId |
| `rawTxHex` | `String` | 是 | 未签名交易序列化 hex |
| `addressType` | `String` | 是 | 地址类型：`p2pkh` / `p2wpkh` / `p2tr` |
| `summary` | `BtcTxSummary` | 是 | 交易摘要 |

### BtcTxSummary

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `inputs` | `BtcInput[]` | 是 | 输入列表（UTXO） |
| `outputs` | `BtcOutput[]` | 是 | 输出列表 |
| `fee` | `String` | 是 | 手续费（satoshi，字符串） |

### BtcInput

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `txHash` | `String` | 是 | 来源交易哈希 |
| `index` | `int` | 是 | 输出索引 |
| `value` | `String` | 是 | UTXO 金额（satoshi） |

### BtcOutput

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `address` | `String` | 是 | 输出地址 |
| `value` | `String` | 是 | 输出金额（satoshi） |

### BtcColdImport（Bitcoin，冷端 → 联网端）

```json
{
  "version": 1,
  "type": "signed-tx",
  "rawTxHex": "<已签名交易的序列化 hex>",
  "txHash": "abc..."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `version` | `int` | 是 | 协议版本号 |
| `type` | `String` | 是 | 固定为 `"signed-tx"` |
| `rawTxHex` | `String` | 是 | 已签名交易序列化 hex |
| `txHash` | `String` | 是 | double SHA-256 交易哈希 |

## 服务层改造

### WalletService 变化

新增多链地址派生入口，现有 Cardano 方法保留向后兼容：

```dart
class WalletService {
  // 保留现有方法（向后兼容）
  Future<String> deriveAddress(String mnemonic, {bool testnet = true}) async { ... }

  /// 派生指定链的地址
  ///
  /// 通过 ChainRegistry 获取对应适配器，从同一助记词派生不同链的地址。
  /// [mnemonic] BIP-39 助记词
  /// [config] 目标链配置
  Future<String> deriveAddressForChain(String mnemonic, ChainConfig config) async {
    final adapter = ChainRegistry.adapterFor(config.chainFamily);
    return adapter.deriveAddress(mnemonic, config);
  }

  /// 获取当前钱包在所有链上的地址
  ///
  /// 返回 Map<chainId, address>
  Future<Map<String, String>> deriveAllAddresses(String mnemonic) async {
    final result = <String, String>{};
    for (final config in ChainRegistry.allConfigs()) {
      result[config.chainId] = await deriveAddressForChain(mnemonic, config);
    }
    return result;
  }
}
```

### TransactionService 变化

新增统一签名入口，自动路由到对应适配器：

```dart
class TransactionService {
  // 保留现有方法（向后兼容）
  Future<ColdImport> signTransaction(ColdExport coldExport) async { ... }

  /// 统一签名入口 — 自动识别链类型并路由到对应适配器
  ///
  /// 解析 JSON 中的 chainId 字段，查 ChainRegistry 获取配置和适配器，
  /// 完成签名后返回链对应的 ColdImport 结构。
  /// [rawJson] 来自扫码或文件导入的 JSON 字符串
  Future<Map<String, dynamic>> signForChain(String rawJson) async {
    final json = jsonDecode(rawJson) as Map<String, dynamic>;
    final chainId = json['chainId'] as String?;

    if (chainId == null) {
      // 向后兼容：无 chainId 视为 Cardano ColdExport
      return _signCardanoLegacy(rawJson);
    }

    final config = ChainRegistry.getConfig(chainId);
    if (config == null) {
      throw UnsupportedError('不支持的链: $chainId');
    }

    final adapter = ChainRegistry.adapterFor(config.chainFamily);
    final mnemonic = await _walletService.loadCurrentMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) {
      throw Exception('当前钱包未初始化或助记词丢失');
    }

    final export = adapter.parseExport(rawJson);
    final result = await adapter.signTransaction(mnemonic, export, config);

    return {
      'version': result.version,
      'type': 'signed-tx',
      'rawTxHex': result.signedTxHex,
      'txHash': result.txHash,
    };
  }
}
```

## UI 变化

### HomeScreen

- **地址展示区**：从单一 Cardano 地址变为多链地址列表
  - 每条链一个可折叠的 ExpansionTile
  - 显示链名 + 地址 + 复制按钮
  - 按链族分组：Cardano → EVM → Bitcoin
- **网络切换按钮移除**：所有链网络固定为测试网，不再需要切换 UI

### ScanTxScreen

扫码或文件导入后的链识别流程：

1. 解析 JSON，读取 `chainId` 字段
2. 查 `ChainRegistry.getConfig(chainId)`
3. 有 `chainId` 且匹配 → 显示链名 + 交易摘要 → 跳转 ConfirmSignScreen
4. 有 `txCbor` 但无 `chainId` → 兼容现有 Cardano ColdExport（向后兼容）
5. 其他情况 → 报错"不支持的交易格式"

### ConfirmSignScreen

根据链族显示不同的摘要信息：

| 链族 | 显示内容 |
|------|---------|
| Cardano | 发送地址、接收地址、资产列表（lovelace + 原生代币）、手续费 (ADA) |
| EVM | 链名、发送地址、接收地址、ETH/ETH 等价物金额、Gas 费用、Nonce |
| Bitcoin | 地址类型、输入列表（UTXO）、输出列表（地址+金额）、手续费 (sats) |

### WalletSetupScreen

钱包详情页（展开某个钱包时）展示所有链的地址：

- 每条链一个卡片，显示链名 + 地址 + 复制按钮
- 地址按链族分组
- 所有链地址从同一助记词派生，无需额外配置

## Flutter 依赖

```yaml
dependencies:
  # 现有（保留）
  cardano_flutter_sdk: ^4.0.1
  cardano_dart_types: any
  bip39_plus: ^1.1.1
  pointycastle: ^4.0.0
  hex: ^0.2.0
  flutter_secure_storage: ^11.0.0
  mobile_scanner: ^7.4.0
  qr_flutter: ^4.1.0
  path_provider: ^2.1.6
  file_picker: ^12.0.0-beta.1

  # 新增 — EVM 链支持
  web3dart: ^2.7.3

  # 新增 — Bitcoin 支持
  bitcoin_flutter: ^2.0.2
```

- `web3dart`：纯 Dart 实现的以太坊工具库，secp256k1 密钥派生、EIP-155 签名、keccak256 哈希、RLP 编解码
- `bitcoin_flutter`：BIP-32/44/84 HD 钱包、多格式地址生成、交易构建与签名

## 目录结构

```
coldwallet-app/lib/
├── main.dart
├── models/
│   ├── wallet_info.dart               # 现有
│   ├── cold_export.dart               # 现有 Cardano 协议
│   ├── cold_import.dart               # 现有 Cardano 协议
│   ├── eth_cold_export.dart           # 新增 EVM 协议
│   ├── eth_cold_import.dart           # 新增 EVM 协议
│   ├── btc_cold_export.dart           # 新增 Bitcoin 协议
│   ├── btc_cold_import.dart           # 新增 Bitcoin 协议
│   ├── chain_config.dart              # 新增 链配置模型
│   └── sign_result.dart               # 新增 签名结果模型
├── services/
│   ├── wallet_service.dart            # 修改：新增 deriveAddressForChain()
│   ├── transaction_service.dart       # 修改：新增 signForChain()
│   ├── secure_storage_service.dart    # 不变
│   ├── chain_registry.dart            # 新增 链注册中心
│   └── adapters/
│       ├── chain_adapter.dart         # 新增 抽象接口
│       ├── cardano_adapter.dart       # 新增（从现有服务提取）
│       ├── evm_adapter.dart           # 新增
│       └── bitcoin_adapter.dart       # 新增
├── screens/
│   ├── home_screen.dart               # 修改：多链地址展示
│   ├── wallet_setup_screen.dart       # 修改：详情页多链地址
│   ├── scan_tx_screen.dart            # 修改：自动识别链类型
│   ├── confirm_sign_screen.dart       # 修改：链相关摘要展示
│   └── dice_entropy_screen.dart       # 不变
└── widgets/
```

## 工作量评估

| 模块 | 工作量 | 说明 |
|------|--------|------|
| ChainConfig + ChainRegistry | 小 | 静态模型 + 配置表 |
| ChainAdapter 接口 | 小 | 抽象类定义 |
| CardanoAdapter | 中 | 从现有服务提取重构，保持向后兼容 |
| EvmAdapter | 中 | secp256k1 派生 + EIP-155 签名，web3dart 封装 |
| BitcoinAdapter | 大 | 三种地址格式 + 多种签名方式 |
| 协议模型 (6 个) | 小 | Dart 模型类 + JSON 序列化 |
| UI 改造 (4 个页面) | 中 | 多链地址展示 + 链路由 + 摘要展示 |
| 文档 + 测试 | 中 | README、PROTOCOL.md、单元测试 |

## 向后兼容

- 现有 Cardano `ColdExport` / `ColdImport` 协议保持不变
- `WalletService.deriveAddress()` 和 `TransactionService.signTransaction()` 方法签名不变
- `ScanTxScreen` 兼容无 `chainId` 字段的旧版 Cardano JSON
- 现有用户数据和助记词不受影响

## 实施阶段

本设计范围较大，建议分三个阶段实施，每个阶段独立可交付：

### 阶段 1：架构基础 + EVM 链支持

1. 创建 `ChainConfig`、`SignResult` 模型
2. 定义 `ChainAdapter` 抽象接口
3. 实现 `CardanoAdapter`（从现有服务提取重构）
4. 实现 `EvmAdapter`（secp256k1 + EIP-155 签名）
5. 实现 `ChainRegistry`（Cardano + 5 条 EVM 链配置）
6. 新增 `EthColdExport` / `EthColdImport` 模型
7. 改造 `WalletService` / `TransactionService` 添加多链入口
8. 更新 UI（HomeScreen 多链地址、ScanTxScreen 链路由、ConfirmSignScreen 链摘要）
9. 更新文档和测试

### 阶段 2：Bitcoin 支持

1. 实现 `BitcoinAdapter`（三种地址格式 + 多种签名方式）
2. 新增 `BtcColdExport` / `BtcColdImport` 模型
3. 在 `ChainRegistry` 中添加 Bitcoin 配置
4. 更新 UI 支持 Bitcoin 地址展示和交易签名
5. 更新文档和测试

### 阶段 3：协议文档与集成验证

1. 扩展 `PROTOCOL.md` 覆盖 EVM 和 Bitcoin 协议
2. 端到端集成测试（冷端签名 → 联网端提交）
3. 构建 Release APK 验证
