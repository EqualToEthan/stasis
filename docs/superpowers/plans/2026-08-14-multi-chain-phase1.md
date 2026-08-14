# 多链冷钱包阶段 1：架构基础 + EVM 链支持 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 coldwallet-app 从单一 Cardano 冷钱包升级为多链架构，阶段 1 完成链适配器基础设施和 EVM 链（Ethereum/BSC/Arbitrum/Polygon/Base）支持。

**Architecture:** 链适配器模式 — `ChainAdapter` 抽象接口 + `CardanoAdapter` / `EvmAdapter` 实现 + `ChainRegistry` 注册中心。现有 Cardano 逻辑提取到适配器中，服务层新增多链入口，UI 层根据 chainId 自动路由。

**Tech Stack:** Flutter 3.11.1, Dart 3.11.1, web3dart (EVM 签名), cardano_flutter_sdk (Cardano), bip39_plus, pointycastle

**Spec:** `docs/superpowers/specs/2026-08-14-multi-chain-cold-wallet-design.md`

---

## 文件清单

### 新增文件

| 文件 | 职责 |
|------|------|
| `lib/models/chain_config.dart` | 链配置模型（chainId, chainFamily, name, network, evmChainId） |
| `lib/models/sign_result.dart` | 通用签名结果模型（signedTxHex, txHash） |
| `lib/models/eth_cold_export.dart` | EVM 链 ColdExport 协议模型 |
| `lib/models/eth_cold_import.dart` | EVM 链 ColdImport 协议模型 |
| `lib/services/adapters/chain_adapter.dart` | 链适配器抽象接口 |
| `lib/services/adapters/cardano_adapter.dart` | Cardano 适配器（从现有服务提取） |
| `lib/services/adapters/evm_adapter.dart` | EVM 适配器（secp256k1 + EIP-155） |
| `lib/services/chain_registry.dart` | 链注册中心 + 内置配置表 |
| `test/models/chain_config_test.dart` | ChainConfig 单元测试 |
| `test/models/eth_cold_export_test.dart` | EthColdExport 序列化测试 |
| `test/services/chain_registry_test.dart` | ChainRegistry 单元测试 |
| `test/services/adapters/cardano_adapter_test.dart` | CardanoAdapter 测试 |
| `test/services/adapters/evm_adapter_test.dart` | EvmAdapter 测试 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `pubspec.yaml` | 添加 web3dart 依赖 |
| `lib/services/wallet_service.dart` | 新增 `deriveAddressForChain()` / `deriveAllAddresses()` |
| `lib/services/transaction_service.dart` | 新增 `signForChain()` 统一签名入口 |
| `lib/screens/home_screen.dart` | 多链地址展示、移除网络切换、通用 JSON 解析 |
| `lib/screens/scan_tx_screen.dart` | 自动识别链类型路由 |
| `lib/screens/tx_detail_screen.dart` | 支持 Cardano 和 EVM 两种摘要展示 |
| `lib/screens/confirm_sign_screen.dart` | 链路由签名（支持 Cardano + EVM） |
| `lib/screens/export_signed_screen.dart` | 通用签名结果展示（不再绑定 ColdImport） |
| `lib/screens/wallet_setup_screen.dart` | 钱包详情展示多链地址 |
| `lib/main.dart` | 注释更新 |
| `lib/models/README.md` | 新增文件条目 |
| `lib/services/README.md` | 新增文件条目 |
| `lib/screens/README.md` | 更新文件条目 |

---

### Task 1: 安装 web3dart 依赖

**Files:**
- Modify: `coldwallet-app/pubspec.yaml:30-46`

- [ ] **Step 1: 添加 web3dart 到 pubspec.yaml**

在 `dependencies` 末尾（`file_picker` 之后）添加：

```yaml
  web3dart: ^2.7.3
```

- [ ] **Step 2: 获取依赖**

Run: `cd coldwallet-app && flutter pub get`
Expected: 依赖解析成功，无冲突

- [ ] **Step 3: 验证 analyze 通过**

Run: `cd coldwallet-app && flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add coldwallet-app/pubspec.yaml coldwallet-app/pubspec.lock
git commit -m "chore: add web3dart dependency for EVM chain support"
```

---

### Task 2: ChainConfig 模型

**Files:**
- Create: `coldwallet-app/lib/models/chain_config.dart`
- Create: `coldwallet-app/test/models/chain_config_test.dart`

- [ ] **Step 1: 编写 ChainConfig 测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/models/chain_config.dart';

void main() {
  group('ChainConfig', () {
    test('constructs with required fields', () {
      const config = ChainConfig(
        chainId: 'evm-11155111',
        chainFamily: 'evm',
        name: 'Ethereum Sepolia',
        network: 'sepolia',
        evmChainId: 11155111,
      );
      expect(config.chainId, 'evm-11155111');
      expect(config.chainFamily, 'evm');
      expect(config.name, 'Ethereum Sepolia');
      expect(config.network, 'sepolia');
      expect(config.evmChainId, 11155111);
    });

    test('Cardano config has null evmChainId', () {
      const config = ChainConfig(
        chainId: 'cardano-preview',
        chainFamily: 'cardano',
        name: 'Cardano Preview',
        network: 'preview',
      );
      expect(config.evmChainId, isNull);
    });

    test('toJson and fromJson roundtrip', () {
      const config = ChainConfig(
        chainId: 'evm-97',
        chainFamily: 'evm',
        name: 'BSC Testnet',
        network: 'testnet',
        evmChainId: 97,
      );
      final json = config.toJson();
      final restored = ChainConfig.fromJson(json);
      expect(restored.chainId, config.chainId);
      expect(restored.chainFamily, config.chainFamily);
      expect(restored.evmChainId, config.evmChainId);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd coldwallet-app && flutter test test/models/chain_config_test.dart`
Expected: FAIL — `chain_config.dart` 不存在

- [ ] **Step 3: 实现 ChainConfig 模型**

```dart
/// 链配置
///
/// 描述一条链的基本信息，供 ChainAdapter 使用。
/// 所有配置在 ChainRegistry 中静态定义，不可运行时修改。
class ChainConfig {
  /// 唯一标识，如 "cardano-preview"、"evm-11155111"
  final String chainId;

  /// 链族标识："cardano"、"evm"
  final String chainFamily;

  /// 显示名称，如 "Cardano Preview"、"Ethereum Sepolia"
  final String name;

  /// 网络标识，如 "preview"、"sepolia"
  final String network;

  /// EVM 链专用链 ID（如 11155111、97），非 EVM 链为 null
  final int? evmChainId;

  const ChainConfig({
    required this.chainId,
    required this.chainFamily,
    required this.name,
    required this.network,
    this.evmChainId,
  });

  factory ChainConfig.fromJson(Map<String, dynamic> json) {
    return ChainConfig(
      chainId: json['chainId'] as String,
      chainFamily: json['chainFamily'] as String,
      name: json['name'] as String,
      network: json['network'] as String,
      evmChainId: json['evmChainId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chainId': chainId,
      'chainFamily': chainFamily,
      'name': name,
      'network': network,
      if (evmChainId != null) 'evmChainId': evmChainId,
    };
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd coldwallet-app && flutter test test/models/chain_config_test.dart`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add coldwallet-app/lib/models/chain_config.dart coldwallet-app/test/models/chain_config_test.dart
git commit -m "feat: add ChainConfig model for multi-chain support"
```

---

### Task 3: SignResult 模型

**Files:**
- Create: `coldwallet-app/lib/models/sign_result.dart`

- [ ] **Step 1: 实现 SignResult 模型**

```dart
/// 签名结果
///
/// 所有链的签名统一返回此结构，包含已签名交易的 hex 编码和交易哈希。
class SignResult {
  /// 已签名交易的 hex 编码（CBOR / RLP 等）
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

  /// 转为通用的 JSON Map（用于 ColdImport 导出）
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': 'signed-tx',
      'rawTxHex': signedTxHex,
      'txHash': txHash,
    };
  }
}
```

- [ ] **Step 2: 验证 analyze 通过**

Run: `cd coldwallet-app && flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add coldwallet-app/lib/models/sign_result.dart
git commit -m "feat: add SignResult model for unified signing output"
```

---

### Task 4: EthColdExport / EthColdImport 模型

**Files:**
- Create: `coldwallet-app/lib/models/eth_cold_export.dart`
- Create: `coldwallet-app/lib/models/eth_cold_import.dart`
- Create: `coldwallet-app/test/models/eth_cold_export_test.dart`

- [ ] **Step 1: 编写 EthColdExport 测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/models/eth_cold_export.dart';

void main() {
  group('EthColdExport', () {
    final sampleJson = {
      'version': 1,
      'type': 'unsigned-tx',
      'chainId': 'evm-11155111',
      'rawTxHex': '0xabcdef',
      'summary': {
        'fromAddress': '0x1234',
        'toAddress': '0x5678',
        'value': '1000000000000000000',
        'fee': '21000000000000',
        'nonce': 42,
      },
    };

    test('fromJson parses correctly', () {
      final export = EthColdExport.fromJson(sampleJson);
      expect(export.version, 1);
      expect(export.type, 'unsigned-tx');
      expect(export.chainId, 'evm-11155111');
      expect(export.rawTxHex, '0xabcdef');
      expect(export.summary.fromAddress, '0x1234');
      expect(export.summary.toAddress, '0x5678');
      expect(export.summary.value, '1000000000000000000');
      expect(export.summary.fee, '21000000000000');
      expect(export.summary.nonce, 42);
    });

    test('toJson roundtrip', () {
      final export = EthColdExport.fromJson(sampleJson);
      final json = export.toJson();
      final restored = EthColdExport.fromJson(json);
      expect(restored.chainId, export.chainId);
      expect(restored.rawTxHex, export.rawTxHex);
      expect(restored.summary.nonce, export.summary.nonce);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd coldwallet-app && flutter test test/models/eth_cold_export_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现 EthColdExport**

```dart
/// EVM 链未签名交易（联网端 → 冷端）
///
/// 包含 RLP 编码的未签名 EIP-1559 交易 hex、chainId 和摘要信息，
/// 通过二维码或文件传递给冷钱包进行离线签名。
class EthColdExport {
  final int version;
  final String type;
  final String chainId;
  final String rawTxHex;
  final EvmTxSummary summary;

  const EthColdExport({
    required this.version,
    required this.type,
    required this.chainId,
    required this.rawTxHex,
    required this.summary,
  });

  factory EthColdExport.fromJson(Map<String, dynamic> json) {
    return EthColdExport(
      version: json['version'] as int,
      type: json['type'] as String,
      chainId: json['chainId'] as String,
      rawTxHex: json['rawTxHex'] as String,
      summary: EvmTxSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'chainId': chainId,
      'rawTxHex': rawTxHex,
      'summary': summary.toJson(),
    };
  }
}

/// EVM 交易摘要
///
/// 包含发送方、接收方、金额、Gas 费用和 nonce，供冷端用户确认。
class EvmTxSummary {
  final String fromAddress;
  final String toAddress;
  final String value;
  final String fee;
  final int nonce;

  const EvmTxSummary({
    required this.fromAddress,
    required this.toAddress,
    required this.value,
    required this.fee,
    required this.nonce,
  });

  factory EvmTxSummary.fromJson(Map<String, dynamic> json) {
    return EvmTxSummary(
      fromAddress: json['fromAddress'] as String,
      toAddress: json['toAddress'] as String,
      value: json['value'] as String,
      fee: json['fee'] as String,
      nonce: json['nonce'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'value': value,
      'fee': fee,
      'nonce': nonce,
    };
  }
}
```

- [ ] **Step 4: 实现 EthColdImport**

```dart
import 'sign_result.dart';

/// EVM 链已签名交易（冷端 → 联网端）
///
/// 包含签名后的完整 RLP 交易 hex 和交易哈希，
/// 联网端导入后可直接提交到链上。
class EthColdImport {
  final int version;
  final String type;
  final String rawTxHex;
  final String txHash;

  const EthColdImport({
    required this.version,
    required this.type,
    required this.rawTxHex,
    required this.txHash,
  });

  factory EthColdImport.fromJson(Map<String, dynamic> json) {
    return EthColdImport(
      version: json['version'] as int,
      type: json['type'] as String,
      rawTxHex: json['rawTxHex'] as String,
      txHash: json['txHash'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'rawTxHex': rawTxHex,
      'txHash': txHash,
    };
  }

  /// 从 SignResult 构造
  factory EthColdImport.fromSignResult(SignResult result) {
    return EthColdImport(
      version: result.version,
      type: 'signed-tx',
      rawTxHex: result.signedTxHex,
      txHash: result.txHash,
    );
  }
}
```

- [ ] **Step 5: 运行测试验证通过**

Run: `cd coldwallet-app && flutter test test/models/eth_cold_export_test.dart`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add coldwallet-app/lib/models/eth_cold_export.dart coldwallet-app/lib/models/eth_cold_import.dart coldwallet-app/test/models/eth_cold_export_test.dart
git commit -m "feat: add EthColdExport and EthColdImport models for EVM protocol"
```

---

### Task 5: ChainAdapter 抽象接口

**Files:**
- Create: `coldwallet-app/lib/services/adapters/chain_adapter.dart`

- [ ] **Step 1: 实现 ChainAdapter 接口**

```dart
import '../../models/chain_config.dart';
import '../../models/sign_result.dart';

/// 链适配器抽象接口
///
/// 每条链族（Cardano / EVM）提供一个实现，
/// 封装地址派生、交易解析和离线签名的链特有逻辑。
abstract class ChainAdapter {
  /// 链族标识，如 "cardano"、"evm"
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
  /// 返回统一的 SignResult
  Future<SignResult> signTransaction(
    String mnemonic,
    dynamic coldExport,
    ChainConfig config,
  );
}
```

- [ ] **Step 2: 验证 analyze 通过**

Run: `cd coldwallet-app && flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add coldwallet-app/lib/services/adapters/chain_adapter.dart
git commit -m "feat: add ChainAdapter abstract interface"
```

---

### Task 6: CardanoAdapter

**Files:**
- Create: `coldwallet-app/lib/services/adapters/cardano_adapter.dart`
- Create: `coldwallet-app/test/services/adapters/cardano_adapter_test.dart`

- [ ] **Step 1: 编写 CardanoAdapter 地址派生测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/models/chain_config.dart';
import 'package:coldwallet_app/services/adapters/cardano_adapter.dart';

void main() {
  group('CardanoAdapter', () {
    late CardanoAdapter adapter;
    late ChainConfig config;

    setUp(() {
      adapter = CardanoAdapter();
      config = const ChainConfig(
        chainId: 'cardano-preview',
        chainFamily: 'cardano',
        name: 'Cardano Preview',
        network: 'preview',
      );
    });

    test('chainFamily is cardano', () {
      expect(adapter.chainFamily, 'cardano');
    });

    test('parseExport parses valid Cardano ColdExport JSON', () {
      final jsonStr = '{"version":1,"type":"unsigned-tx","network":"preview",'
          '"txCbor":"aabb","summary":{"fromAddress":"addr_test1qz",'
          '"toAddress":"addr_test1qy","assets":[{"unit":"lovelace",'
          '"quantity":"5000000"}],"fee":"172000"}}';
      final export = adapter.parseExport(jsonStr);
      expect(export.txCbor, 'aabb');
      expect(export.summary.fromAddress, 'addr_test1qz');
    });

    test('deriveAddress returns bech32 address from known mnemonic', () async {
      // 使用一个固定的测试助记词（仅用于测试）
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      final address = await adapter.deriveAddress(mnemonic, config);
      expect(address, startsWith('addr_test'));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd coldwallet-app && flutter test test/services/adapters/cardano_adapter_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现 CardanoAdapter**

从现有 `WalletService.deriveAddress()` 和 `TransactionService.signTransaction()` 中提取 Cardano 逻辑：

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:cardano_dart_types/cardano_dart_types.dart';
import 'package:cardano_flutter_sdk/cardano_flutter_sdk.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';

import '../../models/chain_config.dart';
import '../../models/cold_export.dart';
import '../../models/sign_result.dart';
import 'chain_adapter.dart';

/// Cardano 链适配器
///
/// 封装 Cardano 的地址派生（CIP-1852）、交易解析（CBOR）和离线签名（Ed25519）。
/// 从现有 WalletService / TransactionService 中提取的链特有逻辑。
class CardanoAdapter implements ChainAdapter {
  @override
  String get chainFamily => 'cardano';

  @override
  Future<String> deriveAddress(String mnemonic, ChainConfig config) async {
    final isTestnet = config.network != 'mainnet';
    final wallet = await WalletFactory.fromMnemonic(
      isTestnet ? NetworkId.testnet : NetworkId.mainnet,
      mnemonic.trim().split(RegExp(r'\s+')),
    );
    final addrKit = await wallet.getPaymentAddressKit(addressIndex: 0);
    return addrKit.address.bech32Encoded;
  }

  @override
  ColdExport parseExport(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return ColdExport.fromJson(json);
  }

  @override
  Future<SignResult> signTransaction(
    String mnemonic,
    dynamic coldExport,
    ChainConfig config,
  ) async {
    final export = coldExport as ColdExport;
    final isTestnet = export.network != 'mainnet';

    final wallet = await WalletFactory.fromMnemonic(
      isTestnet ? NetworkId.testnet : NetworkId.mainnet,
      mnemonic.trim().split(RegExp(r'\s+')),
    );

    final tx = CardanoTransaction.deserializeFromHex(export.txCbor);
    final witnessSet = await wallet.signTransaction(
      tx: tx,
      witnessBech32Addresses: {export.summary.fromAddress},
    );
    final signedTx = tx.copyWithAdditionalSignatures(witnessSet);

    final txHash = _blake2b256(HEX.decode(export.txCbor));

    return SignResult(
      signedTxHex: signedTx.serializeHexString(),
      txHash: HEX.encode(txHash),
    );
  }

  /// 计算 blake2b_256 哈希
  Uint8List _blake2b256(List<int> input) {
    final digest = Blake2bDigest(digestSize: 32);
    digest.update(Uint8List.fromList(input), 0, input.length);
    final result = Uint8List(32);
    digest.doFinal(result, 0);
    return result;
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd coldwallet-app && flutter test test/services/adapters/cardano_adapter_test.dart`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add coldwallet-app/lib/services/adapters/cardano_adapter.dart coldwallet-app/test/services/adapters/cardano_adapter_test.dart
git commit -m "feat: add CardanoAdapter extracted from existing services"
```

---

### Task 7: EvmAdapter

**Files:**
- Create: `coldwallet-app/lib/services/adapters/evm_adapter.dart`
- Create: `coldwallet-app/test/services/adapters/evm_adapter_test.dart`

- [ ] **Step 1: 编写 EvmAdapter 测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/models/chain_config.dart';
import 'package:coldwallet_app/services/adapters/evm_adapter.dart';

void main() {
  group('EvmAdapter', () {
    late EvmAdapter adapter;
    late ChainConfig config;

    setUp(() {
      adapter = EvmAdapter();
      config = const ChainConfig(
        chainId: 'evm-11155111',
        chainFamily: 'evm',
        name: 'Ethereum Sepolia',
        network: 'sepolia',
        evmChainId: 11155111,
      );
    });

    test('chainFamily is evm', () {
      expect(adapter.chainFamily, 'evm');
    });

    test('parseExport parses valid EthColdExport JSON', () {
      final jsonStr = '{"version":1,"type":"unsigned-tx",'
          '"chainId":"evm-11155111","rawTxHex":"0xaabb",'
          '"summary":{"fromAddress":"0x1234","toAddress":"0x5678",'
          '"value":"1000","fee":"21000","nonce":1}}';
      final export = adapter.parseExport(jsonStr);
      expect(export.chainId, 'evm-11155111');
      expect(export.summary.fromAddress, '0x1234');
      expect(export.summary.nonce, 1);
    });

    test('deriveAddress returns 0x-prefixed address from known mnemonic', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      final address = await adapter.deriveAddress(mnemonic, config);
      expect(address, startsWith('0x'));
      expect(address.length, 42); // 0x + 40 hex chars
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd coldwallet-app && flutter test test/services/adapters/evm_adapter_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现 EvmAdapter**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39_plus/bip39_plus.dart' as bip39;
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';
import 'package:web3dart/crypto.dart' as web3crypto;
import 'package:web3dart/web3dart.dart';

import '../../models/chain_config.dart';
import '../../models/eth_cold_export.dart';
import '../../models/sign_result.dart';
import 'chain_adapter.dart';

/// EVM 链适配器
///
/// 覆盖所有 EVM 兼容链（Ethereum、BSC、Arbitrum、Polygon、Base 等），
/// 通过 ChainConfig.evmChainId 区分不同链。
/// 使用 secp256k1 密钥派生（BIP-44 m/44'/60'/0'/0/0）和 EIP-155 签名。
class EvmAdapter implements ChainAdapter {
  @override
  String get chainFamily => 'evm';

  @override
  Future<String> deriveAddress(String mnemonic, ChainConfig config) async {
    final privateKey = _derivePrivateKey(mnemonic);
    final address = await privateKey.extractAddress();
    return address.hex;
  }

  @override
  EthColdExport parseExport(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return EthColdExport.fromJson(json);
  }

  @override
  Future<SignResult> signTransaction(
    String mnemonic,
    dynamic coldExport,
    ChainConfig config,
  ) async {
    final export = coldExport as EthColdExport;
    final privateKey = _derivePrivateKey(mnemonic);
    final chainId = config.evmChainId!;

    // 解码未签名交易的 RLP 数据
    final rawTxBytes = HEX.decode(
      export.rawTxHex.startsWith('0x')
          ? export.rawTxHex.substring(2)
          : export.rawTxHex,
    );

    // 构建 EIP-1559 交易并签名
    final transaction = Transaction(
      from: EthereumAddress.fromHex(export.summary.fromAddress),
      to: EthereumAddress.fromHex(export.summary.toAddress),
      value: EtherAmount.inWei(BigInt.parse(export.summary.value)),
      maxGasPerBlock: null,
      gasPrice: null,
      nonce: export.summary.nonce,
      data: Uint8List(0),
    );

    // 使用 web3dart 签名
    final signedBytes = await _signEip1559(
      rawTxBytes: Uint8List.fromList(rawTxBytes),
      privateKey: privateKey,
      chainId: chainId,
    );

    // 计算交易哈希 (keccak256)
    final txHash = web3crypto.keccak256(signedBytes);

    return SignResult(
      signedTxHex: '0x${HEX.encode(signedBytes)}',
      txHash: '0x${HEX.encode(txHash)}',
    );
  }

  /// 从助记词派生 secp256k1 私钥
  ///
  /// 使用 BIP-39 seed + BIP-32 派生路径 m/44'/60'/0'/0/0
  EthPrivateKey _derivePrivateKey(String mnemonic) {
    final seed = bip39.mnemonicToSeed(mnemonic.trim());
    final masterKey = _deriveMasterKey(seed);
    final childKey = _deriveChildKey(masterKey, [
      0x8000002C, // 44' (hardened)
      0x8000003C, // 60' (hardened, ETH coin type)
      0x80000000, // 0'  (hardened, account)
      0,          // 0   (external chain)
      0,          // 0   (first address)
    ]);
    return EthPrivateKey.fromInt(childKey);
  }

  /// BIP-32 主密钥派生（从 seed 生成 master key）
  _Bip32Key _deriveMasterKey(Uint8List seed) {
    final hmac = Hmac(sha512, utf8.encode('Bitcoin seed'));
    final digest = hmac.process(seed);
    final key = digest.sublist(0, 32);
    final chainCode = digest.sublist(32);
    return _Bip32Key(key: key, chainCode: chainCode);
  }

  /// BIP-32 子密钥派生
  ///
  /// 按路径索引列表逐级派生，0x80000000 以上的索引表示硬化派生。
  BigInt _deriveChildKey(_Bip32Key master, List<int> indices) {
    var key = master.key;
    var chainCode = master.chainCode;

    for (final index in indices) {
      final hmac = Hmac(sha512, chainCode);
      Uint8List data;

      if (index >= 0x80000000) {
        // 硬化派生：0x00 + key + index
        data = Uint8List(37);
        data[0] = 0;
        data.setRange(1, 33, key);
      } else {
        // 普通派生：压缩公钥 + index
        final pubKey = _compressPublicKey(key);
        data = Uint8List(37);
        data.setRange(0, 33, pubKey);
      }

      data[33] = (index >> 24) & 0xff;
      data[34] = (index >> 16) & 0xff;
      data[35] = (index >> 8) & 0xff;
      data[36] = index & 0xff;

      final digest = hmac.process(data);
      final il = digest.sublist(0, 32);
      final ir = digest.sublist(32);

      // secp256k1 曲线阶数
      final n = BigInt.parse(
        'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
        radix: 16,
      );

      final childKey = (BigInt.parse(HEX.encode(il), radix: 16) +
              BigInt.parse(HEX.encode(key), radix: 16)) %
          n;

      key = Uint8List.fromList(
        childKey.toRadixString(16).padLeft(64, '0').codeUnits.map((c) {
          // 将 hex string 转回 bytes
          return c;
        }).toList(),
      );
      // 重新正确编码为字节
      final hexStr = childKey.toRadixString(16).padLeft(64, '0');
      key = HEX.decode(hexStr) as Uint8List;
      chainCode = ir;
    }

    return BigInt.parse(HEX.encode(key), radix: 16);
  }

  /// secp256k1 公钥压缩
  Uint8List _compressPublicKey(Uint8List privateKey) {
    final params = ECCurve_secp256k1();
    final ecPoint = params.G * BigInt.parse(HEX.encode(privateKey), radix: 16);
    return ecPoint!.getEncoded(true);
  }

  /// EIP-1559 交易签名
  ///
  /// 对 RLP 编码的未签名交易进行 ECDSA 签名，
  /// 返回包含签名的已签名交易 RLP 编码。
  Future<Uint8List> _signEip1559({
    required Uint8List rawTxBytes,
    required EthPrivateKey privateKey,
    required int chainId,
  }) async {
    // EIP-1559 交易的类型前缀为 0x02
    // rawTxBytes 已包含 0x02 前缀 + RLP 编码
    // 签名哈希 = keccak256(0x02 + RLP(unsigned_fields))
    final txHash = web3crypto.keccak256(rawTxBytes);

    // ECDSA 签名
    final credentials = privateKey;
    final signature = await credentials.signToSignature(txHash);

    // 从 RLP 解码未签名字段
    // EIP-1559 未签名: [chainId, nonce, maxPriorityFeePerGas, maxFeePerGas,
    //                   gasLimit, to, value, data, accessList]
    // EIP-1559 已签名: [chainId, nonce, maxPriorityFeePerGas, maxFeePerGas,
    //                   gasLimit, to, value, data, accessList, yParity, r, s]
    final stripped = rawTxBytes.sublist(1); // 去掉 0x02 前缀
    final decoded = _rlpDecode(stripped) as List<dynamic>;

    final yParity = signature.v - BigInt.from(27);
    final r = signature.r;
    final s = signature.s;

    final signed = <dynamic>[...decoded, yParity, r, s];
    final rlpEncoded = _rlpEncode(signed);

    // 加上 EIP-1559 类型前缀
    return Uint8List.fromList([0x02, ...rlpEncoded]);
  }

  /// 简易 RLP 解码
  dynamic _rlpDecode(Uint8List data) {
    if (data.length == 1 && data[0] < 0x80) {
      return data;
    }
    final result = _rlpDecodeItem(data, 0);
    return result.value;
  }

  _RlpResult _rlpDecodeItem(Uint8List data, int offset) {
    final prefix = data[offset];

    if (prefix < 0x80) {
      return _RlpResult(Uint8List.fromList([prefix]), offset + 1);
    } else if (prefix <= 0xb7) {
      final length = prefix - 0x80;
      return _RlpResult(data.sublist(offset + 1, offset + 1 + length), offset + 1 + length);
    } else if (prefix <= 0xbf) {
      final lenBytes = prefix - 0xb7;
      int length = 0;
      for (int i = 0; i < lenBytes; i++) {
        length = (length << 8) | data[offset + 1 + i];
      }
      return _RlpResult(
        data.sublist(offset + 1 + lenBytes, offset + 1 + lenBytes + length),
        offset + 1 + lenBytes + length,
      );
    } else if (prefix <= 0xf7) {
      final length = prefix - 0xc0;
      final list = <dynamic>[];
      int pos = offset + 1;
      while (pos < offset + 1 + length) {
        final item = _rlpDecodeItem(data, pos);
        list.add(item.value);
        pos = item.nextOffset;
      }
      return _RlpResult(list, offset + 1 + length);
    } else {
      final lenBytes = prefix - 0xf7;
      int length = 0;
      for (int i = 0; i < lenBytes; i++) {
        length = (length << 8) | data[offset + 1 + i];
      }
      final list = <dynamic>[];
      int pos = offset + 1 + lenBytes;
      while (pos < offset + 1 + lenBytes + length) {
        final item = _rlpDecodeItem(data, pos);
        list.add(item.value);
        pos = item.nextOffset;
      }
      return _RlpResult(list, offset + 1 + lenBytes + length);
    }
  }

  /// 简易 RLP 编码
  Uint8List _rlpEncode(dynamic input) {
    if (input is Uint8List) {
      if (input.length == 1 && input[0] < 0x80) {
        return input;
      }
      return Uint8List.fromList([
        ..._rlpEncodeLength(input.length, 0x80),
        ...input,
      ]);
    } else if (input is List) {
      final encoded = input.map((item) => _rlpEncode(item)).toList();
      final totalLength = encoded.fold<int>(0, (sum, e) => sum + e.length);
      return Uint8List.fromList([
        ..._rlpEncodeLength(totalLength, 0xc0),
        ...encoded.expand((e) => e),
      ]);
    } else if (input is BigInt) {
      if (input == BigInt.zero) {
        return Uint8List.fromList([0x80]); // 空字节串
      }
      final hex = input.toRadixString(16);
      final bytes = HEX.decode(hex.length.isOdd ? '0$hex' : hex) as Uint8List;
      return _rlpEncode(bytes);
    } else if (input is int) {
      return _rlpEncode(BigInt.from(input));
    }
    throw ArgumentError('Unsupported RLP type: ${input.runtimeType}');
  }

  Uint8List _rlpEncodeLength(int length, int offset) {
    if (length < 56) {
      return Uint8List.fromList([offset + length]);
    }
    final lenBytes = _intToBytes(length);
    return Uint8List.fromList([offset + 55 + lenBytes.length, ...lenBytes]);
  }

  Uint8List _intToBytes(int value) {
    if (value == 0) return Uint8List.fromList([0]);
    final bytes = <int>[];
    var v = value;
    while (v > 0) {
      bytes.insert(0, v & 0xff);
      v >>= 8;
    }
    return Uint8List.fromList(bytes);
  }
}

class _Bip32Key {
  final Uint8List key;
  final Uint8List chainCode;
  _Bip32Key({required this.key, required this.chainCode});
}

class _RlpResult {
  final dynamic value;
  final int nextOffset;
  _RlpResult(this.value, this.nextOffset);
}
```

> **实现说明**：`EvmAdapter` 包含自实现的 BIP-32 HD 密钥派生和 RLP 编解码器，以避免额外依赖。如果 `web3dart` 的 API 提供了更简洁的方法，实现时优先使用。

- [ ] **Step 4: 运行测试验证通过**

Run: `cd coldwallet-app && flutter test test/services/adapters/evm_adapter_test.dart`
Expected: All tests pass（deriveAddress 测试可能较慢）

- [ ] **Step 5: Commit**

```bash
git add coldwallet-app/lib/services/adapters/evm_adapter.dart coldwallet-app/test/services/adapters/evm_adapter_test.dart
git commit -m "feat: add EvmAdapter with BIP-44 derivation and EIP-155 signing"
```

---

### Task 8: ChainRegistry

**Files:**
- Create: `coldwallet-app/lib/services/chain_registry.dart`
- Create: `coldwallet-app/test/services/chain_registry_test.dart`

- [ ] **Step 1: 编写 ChainRegistry 测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/services/chain_registry.dart';
import 'package:coldwallet_app/services/adapters/cardano_adapter.dart';
import 'package:coldwallet_app/services/adapters/evm_adapter.dart';

void main() {
  group('ChainRegistry', () {
    test('getConfig returns Cardano preview config', () {
      final config = ChainRegistry.getConfig('cardano-preview');
      expect(config, isNotNull);
      expect(config!.chainFamily, 'cardano');
      expect(config.network, 'preview');
      expect(config.evmChainId, isNull);
    });

    test('getConfig returns Ethereum Sepolia config', () {
      final config = ChainRegistry.getConfig('evm-11155111');
      expect(config, isNotNull);
      expect(config!.chainFamily, 'evm');
      expect(config.evmChainId, 11155111);
    });

    test('getConfig returns BSC Testnet config', () {
      final config = ChainRegistry.getConfig('evm-97');
      expect(config, isNotNull);
      expect(config!.evmChainId, 97);
    });

    test('getConfig returns null for unknown chain', () {
      expect(ChainRegistry.getConfig('unknown'), isNull);
    });

    test('adapterFor returns CardanoAdapter for cardano', () {
      final adapter = ChainRegistry.adapterFor('cardano');
      expect(adapter, isA<CardanoAdapter>());
    });

    test('adapterFor returns EvmAdapter for evm', () {
      final adapter = ChainRegistry.adapterFor('evm');
      expect(adapter, isA<EvmAdapter>());
    });

    test('adapterFor throws for unknown family', () {
      expect(() => ChainRegistry.adapterFor('unknown'), throwsA(isA<UnsupportedError>()));
    });

    test('allConfigs returns 6 entries', () {
      expect(ChainRegistry.allConfigs().length, 6);
    });

    test('configsForFamily evm returns 5 entries', () {
      expect(ChainRegistry.configsForFamily('evm').length, 5);
    });

    test('configsForFamily cardano returns 1 entry', () {
      expect(ChainRegistry.configsForFamily('cardano').length, 1);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd coldwallet-app && flutter test test/services/chain_registry_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现 ChainRegistry**

```dart
import '../models/chain_config.dart';
import 'adapters/cardano_adapter.dart';
import 'adapters/chain_adapter.dart';
import 'adapters/evm_adapter.dart';

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
  };

  /// 根据链族获取适配器实例
  static ChainAdapter adapterFor(String chainFamily) {
    switch (chainFamily) {
      case 'cardano':
        return CardanoAdapter();
      case 'evm':
        return EvmAdapter();
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

- [ ] **Step 4: 运行测试验证通过**

Run: `cd coldwallet-app && flutter test test/services/chain_registry_test.dart`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add coldwallet-app/lib/services/chain_registry.dart coldwallet-app/test/services/chain_registry_test.dart
git commit -m "feat: add ChainRegistry with 6 chain configs"
```

---

### Task 9: 服务层多链入口

**Files:**
- Modify: `coldwallet-app/lib/services/wallet_service.dart:58-78`
- Modify: `coldwallet-app/lib/services/transaction_service.dart:1-69`

- [ ] **Step 1: 在 WalletService 中新增多链方法**

在 `wallet_service.dart` 的 `// ─── Cardano 链上操作 ───` 段落之后，添加：

```dart
  // ─── 多链地址派生 ──────────────────────────────────────────

  /// 派生指定链的地址
  ///
  /// 通过 ChainRegistry 获取对应适配器，从同一助记词派生不同链的地址。
  Future<String> deriveAddressForChain(String mnemonic, ChainConfig config) async {
    final adapter = ChainRegistry.adapterFor(config.chainFamily);
    return adapter.deriveAddress(mnemonic, config);
  }

  /// 获取当前钱包在所有链上的地址
  ///
  /// 返回 Map<chainId, address>，遍历 ChainRegistry 中所有配置。
  Future<Map<String, String>> deriveAllAddresses(String mnemonic) async {
    final result = <String, String>{};
    for (final config in ChainRegistry.allConfigs()) {
      result[config.chainId] = await deriveAddressForChain(mnemonic, config);
    }
    return result;
  }
```

在文件顶部添加导入：

```dart
import '../models/chain_config.dart';
import 'chain_registry.dart';
```

- [ ] **Step 2: 在 TransactionService 中新增统一签名入口**

在 `transaction_service.dart` 的 `signTransaction` 方法之后，添加：

```dart
  /// 统一签名入口 — 自动识别链类型并路由到对应适配器
  ///
  /// 解析 JSON 中的 chainId 字段，查 ChainRegistry 获取配置和适配器，
  /// 完成签名后返回链对应的 ColdImport 结构 Map。
  /// 无 chainId 字段的 JSON 视为 Cardano ColdExport（向后兼容）。
  Future<Map<String, dynamic>> signForChain(String rawJson) async {
    final json = jsonDecode(rawJson) as Map<String, dynamic>;
    final chainId = json['chainId'] as String?;

    if (chainId == null) {
      // 向后兼容：无 chainId 视为 Cardano ColdExport
      return _signCardanoLegacy(json);
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

  /// Cardano 旧版签名（向后兼容）
  Map<String, dynamic> _signCardanoLegacy(Map<String, dynamic> json) {
    final coldExport = ColdExport.fromJson(json);
    // 异步签名由 signTransaction 处理，这里只返回解析结果供调用方使用
    return coldExport.toJson();
  }
```

在文件顶部添加导入：

```dart
import 'chain_registry.dart';
```

注意：`signForChain` 需要异步调用适配器的 `signTransaction`，所以实际实现中 `_signCardanoLegacy` 应返回 ColdExport 供调用方走原有 `signTransaction(ColdExport)` 流程。完整实现见下方修正版。

- [ ] **Step 3: 修正 signForChain 的异步实现**

将 `signForChain` 方法替换为：

```dart
  /// 统一签名入口 — 自动识别链类型并路由到对应适配器
  ///
  /// [rawJson] 来自扫码或文件导入的 JSON 字符串。
  /// 无 chainId 字段时视为 Cardano ColdExport（向后兼容）。
  /// 返回通用的签名结果 JSON Map。
  Future<Map<String, dynamic>> signForChain(String rawJson) async {
    final json = jsonDecode(rawJson) as Map<String, dynamic>;
    final chainId = json['chainId'] as String?;

    final mnemonic = await _walletService.loadCurrentMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) {
      throw Exception('当前钱包未初始化或助记词丢失');
    }

    if (chainId == null) {
      // 向后兼容：Cardano ColdExport
      final coldExport = ColdExport.fromJson(json);
      final coldImport = await signTransaction(coldExport);
      return coldImport.toJson();
    }

    final config = ChainRegistry.getConfig(chainId);
    if (config == null) {
      throw UnsupportedError('不支持的链: $chainId');
    }

    final adapter = ChainRegistry.adapterFor(config.chainFamily);
    final export = adapter.parseExport(rawJson);
    final result = await adapter.signTransaction(mnemonic, export, config);

    return {
      'version': result.version,
      'type': 'signed-tx',
      'rawTxHex': result.signedTxHex,
      'txHash': result.txHash,
    };
  }
```

- [ ] **Step 4: 验证 analyze 通过**

Run: `cd coldwallet-app && flutter analyze`
Expected: No issues found

- [ ] **Step 5: 运行现有测试确保不破坏**

Run: `cd coldwallet-app && flutter test`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add coldwallet-app/lib/services/wallet_service.dart coldwallet-app/lib/services/transaction_service.dart
git commit -m "feat: add multi-chain entry points to WalletService and TransactionService"
```

---

### Task 10: HomeScreen 多链地址展示

**Files:**
- Modify: `coldwallet-app/lib/screens/home_screen.dart`

- [ ] **Step 1: 移除网络切换按钮，添加多链地址展示**

主要修改点：

1. **移除 `_toggleNetwork()` 方法和 AppBar 中的网络切换按钮**（第 101-105 行、第 113-133 行）
2. **AppBar title 改为 `'Stasis'`**（不再写死 "Cardano 冷钱包"）
3. **在钱包选择器下方添加多链地址列表**（折叠式 ExpansionTile）

在 `_buildWalletSelector()` 调用后添加地址展示区域：

```dart
  /// 构建多链地址展示列表
  Widget _buildMultiChainAddresses() {
    if (!_hasWallets) return const SizedBox.shrink();

    return FutureBuilder<Map<String, String>>(
      future: _loadAllAddresses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final addresses = snapshot.data ?? {};
        if (addresses.isEmpty) return const SizedBox.shrink();

        final configs = ChainRegistry.allConfigs();
        return Column(
          children: configs.map((config) {
            final addr = addresses[config.chainId] ?? '—';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: _chainIcon(config.chainFamily),
                title: Text(config.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                  _truncateAddress(addr),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: addr));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已复制 ${config.name} 地址')),
                    );
                  },
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: addr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已复制 ${config.name} 地址')),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<Map<String, String>> _loadAllAddresses() async {
    final mnemonic = await _walletService.loadCurrentMnemonic();
    if (mnemonic == null) return {};
    return _walletService.deriveAllAddresses(mnemonic);
  }

  String _truncateAddress(String addr) {
    if (addr.length <= 20) return addr;
    return '${addr.substring(0, 10)}...${addr.substring(addr.length - 8)}';
  }

  Icon _chainIcon(String family) {
    switch (family) {
      case 'cardano':
        return const Icon(Icons.currency_bitcoin, color: Colors.blue);
      case 'evm':
        return const Icon(Icons.link, color: Colors.purple);
      default:
        return const Icon(Icons.circle_outlined);
    }
  }
```

4. **修改 `_parseAndNavigate` 方法支持通用 JSON 解析**：

```dart
  void _parseAndNavigate(String jsonStr) {
    if (jsonStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据不能为空')),
      );
      return;
    }
    try {
      // 传递原始 JSON 字符串，由 TxDetailScreen 解析路由
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TxDetailScreen(rawJson: jsonStr),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解析失败: $e'), backgroundColor: Colors.red),
      );
    }
  }
```

需要添加导入：
```dart
import 'package:flutter/services.dart';
import '../services/chain_registry.dart';
```

- [ ] **Step 2: 验证 analyze 通过**

Run: `cd coldwallet-app && flutter analyze`
Expected: No issues（可能需要先更新 TxDetailScreen）

- [ ] **Step 3: Commit**

```bash
git add coldwallet-app/lib/screens/home_screen.dart
git commit -m "feat: HomeScreen multi-chain address display and generic JSON parsing"
```

---

### Task 11: TxDetailScreen 链感知改造

**Files:**
- Modify: `coldwallet-app/lib/screens/tx_detail_screen.dart`

- [ ] **Step 1: 改造为接收 rawJson 并根据链类型展示不同摘要**

将 `TxDetailScreen` 从接收 `ColdExport` 改为接收 `String rawJson`，根据 chainId 自动展示 Cardano 或 EVM 摘要。

关键修改：
- 构造函数改为 `TxDetailScreen({required this.rawJson})`
- `initState` 中解析 JSON，识别链类型
- Cardano 摘要：显示网络、发送方、接收方、资产列表、手续费 (ADA)
- EVM 摘要：显示链名、发送方、接收方、金额 (ETH)、Gas 费用、Nonce

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/cold_export.dart';
import '../models/eth_cold_export.dart';
import '../services/chain_registry.dart';
import 'confirm_sign_screen.dart';

/// 交易详情页面
///
/// 根据 JSON 中的 chainId 字段自动识别链类型，
/// 展示对应的交易摘要信息，用户确认后跳转签名页面。
class TxDetailScreen extends StatelessWidget {
  /// 原始 JSON 字符串（支持 Cardano ColdExport 和 EVM EthColdExport）
  final String rawJson;

  const TxDetailScreen({super.key, required this.rawJson});

  @override
  Widget build(BuildContext context) {
    final json = jsonDecode(rawJson) as Map<String, dynamic>;
    final chainId = json['chainId'] as String?;

    if (chainId == null) {
      // Cardano 旧版格式
      final coldExport = ColdExport.fromJson(json);
      return _buildCardanoDetail(context, coldExport);
    }

    // EVM 格式
    final config = ChainRegistry.getConfig(chainId);
    final ethExport = EthColdExport.fromJson(json);
    return _buildEvmDetail(context, ethExport, config?.name ?? chainId);
  }

  Widget _buildCardanoDetail(BuildContext context, ColdExport export) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cardano 交易详情')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(title: '网络', value: export.network, icon: Icons.network_check),
            const SizedBox(height: 12),
            _buildInfoCard(title: '发送方', value: export.summary.fromAddress, icon: Icons.arrow_upward),
            const SizedBox(height: 12),
            _buildInfoCard(title: '接收方', value: export.summary.toAddress, icon: Icons.arrow_downward),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: '金额',
              value: export.summary.assets.map(_formatAsset).join('\n'),
              icon: Icons.paid,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(title: '手续费', value: _formatAda(export.summary.fee), icon: Icons.receipt),
            const Spacer(),
            _buildConfirmButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEvmDetail(BuildContext context, EthColdExport export, String chainName) {
    return Scaffold(
      appBar: AppBar(title: const Text('EVM 交易详情')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(title: '链', value: chainName, icon: Icons.link),
            const SizedBox(height: 12),
            _buildInfoCard(title: '发送方', value: export.summary.fromAddress, icon: Icons.arrow_upward),
            const SizedBox(height: 12),
            _buildInfoCard(title: '接收方', value: export.summary.toAddress, icon: Icons.arrow_downward),
            const SizedBox(height: 12),
            _buildInfoCard(title: '金额', value: _formatWei(export.summary.value), icon: Icons.paid),
            const SizedBox(height: 12),
            _buildInfoCard(title: 'Gas 费用', value: _formatWei(export.summary.fee), icon: Icons.receipt),
            const SizedBox(height: 12),
            _buildInfoCard(title: 'Nonce', value: '${export.summary.nonce}', icon: Icons.numbers),
            const Spacer(),
            _buildConfirmButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmSignScreen(rawJson: rawJson),
          ),
        );
      },
      icon: const Icon(Icons.edit),
      label: const Text('确认并签名'),
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
    );
  }

  String _formatAda(String lovelace) {
    try {
      final value = int.parse(lovelace);
      return '${(value / 1000000).toStringAsFixed(6)} ADA';
    } catch (_) {
      return '$lovelace lovelace';
    }
  }

  String _formatAsset(AssetAmount asset) {
    if (asset.unit == 'lovelace') return _formatAda(asset.quantity);
    return '${asset.quantity} ${asset.displayLabel}';
  }

  String _formatWei(String wei) {
    try {
      final value = BigInt.parse(wei);
      final eth = value / BigInt.from(10).pow(18);
      return '${eth.toStringAsFixed(6)} ETH';
    } catch (_) {
      return '$wei wei';
    }
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blueGrey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 验证 analyze 通过**

Run: `cd coldwallet-app && flutter analyze`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add coldwallet-app/lib/screens/tx_detail_screen.dart
git commit -m "feat: TxDetailScreen supports Cardano and EVM transaction summaries"
```

---

### Task 12: ConfirmSignScreen + ExportSignedScreen 链路由

**Files:**
- Modify: `coldwallet-app/lib/screens/confirm_sign_screen.dart`
- Modify: `coldwallet-app/lib/screens/export_signed_screen.dart`

- [ ] **Step 1: 改造 ConfirmSignScreen 为通用签名页**

将 `ConfirmSignScreen` 从接收 `ColdExport` 改为接收 `String rawJson`，使用 `TransactionService.signForChain()` 统一签名：

关键修改：
- 构造函数改为 `ConfirmSignScreen({required this.rawJson})`
- `_verifyAndSign()` 中调用 `transactionService.signForChain(widget.rawJson)`
- 签名结果传给 `ExportSignedScreen` 时使用 `Map<String, dynamic>` 参数

```dart
// _verifyAndSign 核心逻辑修改：
final transactionService = TransactionService(_walletService);
final signedResult = await transactionService.signForChain(widget.rawJson);

if (!mounted) return;
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => ExportSignedScreen(signedJson: signedResult),
  ),
);
```

- [ ] **Step 2: 改造 ExportSignedScreen 为通用导出页**

将 `ExportSignedScreen` 从接收 `ColdImport` 改为接收 `Map<String, dynamic> signedJson`：

关键修改：
- 构造函数改为 `ExportSignedScreen({required this.signedJson})`
- `_payload` 改为 `jsonEncode(widget.signedJson)`
- `_copyTxHash` 使用 `widget.signedJson['txHash']`

- [ ] **Step 3: 验证 analyze 通过**

Run: `cd coldwallet-app && flutter analyze`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add coldwallet-app/lib/screens/confirm_sign_screen.dart coldwallet-app/lib/screens/export_signed_screen.dart
git commit -m "feat: ConfirmSignScreen and ExportSignedScreen support multi-chain signing"
```

---

### Task 13: ScanTxScreen 链路由

**Files:**
- Modify: `coldwallet-app/lib/screens/scan_tx_screen.dart`

- [ ] **Step 1: 更新扫码解析逻辑**

将 `ScanTxScreen` 的 `_onDetect` 改为传递原始 JSON 到 `TxDetailScreen`（不再直接解析为 ColdExport）：

```dart
void _onDetect(BarcodeCapture capture) {
  if (_scanned) return;

  final barcode = capture.barcodes.firstOrNull;
  final rawValue = barcode?.rawValue;
  if (rawValue == null || rawValue.isEmpty) return;

  setState(() => _scanned = true);

  try {
    // 验证是合法 JSON，然后传递原始字符串
    jsonDecode(rawValue);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TxDetailScreen(rawJson: rawValue),
      ),
    );
  } catch (e) {
    setState(() => _scanned = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('无法解析二维码: $e')),
    );
  }
}
```

移除 `import '../models/cold_export.dart';`，因为不再直接使用。

- [ ] **Step 2: 验证 analyze 通过**

Run: `cd coldwallet-app && flutter analyze`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add coldwallet-app/lib/screens/scan_tx_screen.dart
git commit -m "feat: ScanTxScreen routes to chain-aware TxDetailScreen"
```

---

### Task 14: WalletSetupScreen 多链地址详情

**Files:**
- Modify: `coldwallet-app/lib/screens/wallet_setup_screen.dart`

- [ ] **Step 1: 修改钱包展开详情为多链地址**

当前 `_expandWallet` 方法（约第 55-82 行）只派生 Cardano 地址。修改为调用 `deriveAllAddresses()` 展示所有链地址：

```dart
Future<void> _expandWallet(WalletInfo wallet) async {
  if (_expandedWalletId == wallet.id) {
    setState(() {
      _expandedWalletId = null;
      _expandedAddress = null;
      _expandedMnemonic = null;
    });
    return;
  }
  final prevWallet = await _walletService.getCurrentWallet();
  await _walletService.switchWallet(wallet.id);
  final m = await _walletService.loadCurrentMnemonic();
  // 派生所有链的地址
  Map<String, String> allAddresses = {};
  if (m != null) {
    allAddresses = await _walletService.deriveAllAddresses(m);
  }
  if (prevWallet != null) {
    await _walletService.switchWallet(prevWallet.id);
  }
  if (!mounted) return;
  setState(() {
    _expandedWalletId = wallet.id;
    _expandedAddresses = allAddresses; // 新增字段
    _expandedMnemonic = m;
  });
}
```

在状态变量中：
- 移除 `String? _expandedAddress;`
- 新增 `Map<String, String>? _expandedAddresses;`

在钱包详情的 UI 部分，将单一地址展示替换为遍历 `_expandedAddresses` 显示每条链的地址卡片。

- [ ] **Step 2: 验证 analyze 通过**

Run: `cd coldwallet-app && flutter analyze`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add coldwallet-app/lib/screens/wallet_setup_screen.dart
git commit -m "feat: WalletSetupScreen shows multi-chain addresses in wallet detail"
```

---

### Task 15: main.dart 注释更新 + 文档更新

**Files:**
- Modify: `coldwallet-app/lib/main.dart:1-4`
- Create/Modify: `coldwallet-app/lib/models/README.md`
- Create/Modify: `coldwallet-app/lib/services/README.md`
- Create/Modify: `coldwallet-app/lib/screens/README.md`

- [ ] **Step 1: 更新 main.dart 文件头注释**

```dart
/// 多链冷钱包 App 入口
///
/// 完全离线的冷钱包应用，支持 Cardano 和 EVM 兼容链。
/// 用于助记词管理、多链地址派生、离线签名和交易导出。
/// 通过二维码或文件与联网端（观察钱包）交互。
```

- [ ] **Step 2: 更新模块 README 文档**

更新 `lib/models/README.md`、`lib/services/README.md`、`lib/screens/README.md`，添加新增文件的条目和功能说明。

- [ ] **Step 3: 运行全量 analyze**

Run: `cd coldwallet-app && flutter analyze`
Expected: No issues found

- [ ] **Step 4: 运行全量测试**

Run: `cd coldwallet-app && flutter test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "docs: update module READMEs and main.dart comments for multi-chain"
```

---

### Task 16: 构建验证

- [ ] **Step 1: Debug APK 构建**

Run: `cd coldwallet-app && flutter build apk --debug`
Expected: BUILD SUCCESSFUL

- [ ] **Step 2: 安装并手动验证**

安装 APK 到模拟器或设备，验证：
1. 首页显示多链地址列表（Cardano + 5 条 EVM 链）
2. 钱包管理页面展开后显示所有链地址
3. 扫码/导入功能正常（向后兼容旧 Cardano JSON）

- [ ] **Step 3: Commit 最终构建**

```bash
git add -A
git commit -m "chore: debug APK build verification for multi-chain phase 1"
```
