# Cardano Staking 功能设计文档

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:writing-plans to create the implementation plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 coldwallet 项目添加完整的 Cardano 质押功能，支持 stake key registration、delegation、reward withdrawal、stake deregistration 四个核心操作。

**Architecture:** 扩展现有 ColdExport/ColdImport 模型，在 CardanoAdapter 中加 stake key witness 签名逻辑，观察钱包端新增 StakingScreen 和 StakeTransactionBuilder，冷钱包端无需改 UI（签名逻辑自动适配）。

**Tech Stack:** Flutter, cardano_flutter_sdk, cardano_dart_types, Blockfrost API

---

## 1. 需求概述

### 1.1 核心操作

| 操作 | 说明 | 交易结构 |
|------|------|----------|
| **Stake key registration + delegation** | 首次质押，合并在一笔交易 | certificates: [stake_registration, stake_delegation] |
| **Re-delegation** | 更换 stake pool | certificates: [stake_delegation] |
| **Reward withdrawal** | 提取质押奖励 | withdrawals: {reward_address: amount} |
| **Stake deregistration** | 解除质押，回收 2 ADA deposit | certificates: [stake_deregistration] |

### 1.2 设计决策

| 决策 | 选择 | 原因 |
|------|------|------|
| Stake pool 选择 | 手动输入 pool ID（Bech32） | 简单直接，避免列表查询复杂度 |
| 首次质押 | Registration + delegation 合并 | Cardano 原生支持，用户操作一次 |
| Stake key path | `m/1852'/1815'/0'/2/0` | CIP-1852 标准 |
| 模型扩展 | ColdExport 加可选字段 | 向后兼容，payment 交易不受影响 |
| Add wallet | 合并 QR 导入 payment + stake 地址 | 一次扫码搞定 |

---

## 2. 架构概览

### 2.1 数据流

```
观察钱包（coldwallet-watch）                    冷钱包（coldwallet-app）
──────────────────────                        ─────────────────────
StakingScreen
  ├─ 输入 pool ID（pool1...）
  ├─ Blockfrost 查询 pool 信息
  └─ StakeTransactionBuilder 构建交易
       ↓
ExportTxScreen（QR/文件导出）
       ↓ ColdExport JSON
       ↓  {txCbor, certificates, withdrawals, stakeKeyPath}
       ↓
                                              ScanTxScreen / ImportFileScreen
                                               ↓
                                              ConfirmSignScreen
                                               ├─ PIN 验证
                                               └─ signForChain → CardanoAdapter
                                                    ├─ payment key witness
                                                    └─ stake key witness（新增）
                                                       ↓
                                              ExportSignedScreen（QR/文件导出）
                                                       ↓
ImportSignedScreen
  ↓
SubmitTx → 链上确认
```

### 2.2 组件关系

```
coldwallet-watch/lib/
  ├─ screens/staking_screen.dart              # 质押 UI 入口
  ├─ services/stake_transaction_builder.dart  # 构建质押交易 CBOR
  ├─ services/blockfrost_service.dart         # +pool/stake 状态查询
  └─ models/stake_info.dart                   # 质押状态模型

coldwallet-app/lib/
  ├─ models/certificate.dart                  # Certificate 模型（新建）
  ├─ models/cold_export.dart                  # +certificates / withdrawals / stakeKeyPath
  ├─ services/wallet_service.dart             # +deriveStakeKey()
  ├─ services/adapters/cardano_adapter.dart   # +stake key witness 签名
  └─ screens/home_screen.dart                 # 显示 stake address
```

---

## 3. 数据模型

### 3.1 Certificate（新建）

```dart
enum CertificateType {
  stakeRegistration,
  stakeDelegation,
  stakeDeregistration,
}

class Certificate {
  final CertificateType type;
  final String stakeCredential;   // blake2b_224(stake pubkey), 28 字节 hex
  final String? poolKeyHash;      // delegation 时用，28 字节 hex
  
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'stakeCredential': stakeCredential,
    if (poolKeyHash != null) 'poolKeyHash': poolKeyHash,
  };
  
  factory Certificate.fromJson(Map<String, dynamic> json) {
    return Certificate(
      type: CertificateType.values.firstWhere((e) => e.name == json['type']),
      stakeCredential: json['stakeCredential'] as String,
      poolKeyHash: json['poolKeyHash'] as String?,
    );
  }
}
```

### 3.2 ColdExport 扩展

```dart
class ColdExport {
  final String network;
  final String txCbor;
  final TransactionSummary summary;
  
  // 质押交易专用（可选，payment 交易时为 null）
  final List<Certificate>? certificates;
  final Map<String, int>? withdrawals;   // reward_address → amount (lovelace)
  final String? stakeKeyPath;            // 如 "m/1852'/1815'/0'/2/0"
  
  // fromJson / toJson 加对应字段，无字段时默认为 null（向后兼容）
}
```

### 3.3 Stake key 派生

- **Path**: `m/1852'/1815'/0'/2/0`（CIP-1852 标准 stake key path）
- **Stake credential**: `blake2b_224(stake_public_key)`（28 字节）
- **Stake address**: `stake_credential + network_tag`，Bech32 编码（`stake_test1...` / `stake1...`）

```dart
// wallet_service.dart 新增
Future<StakeKeyPair> deriveStakeKey(String mnemonic, {int accountIndex = 0}) async {
  final rootKey = await _deriveRootKey(mnemonic);
  final stakeKey = rootKey
      .deriveChild(1852, hardened: true)
      .deriveChild(1815, hardened: true)
      .deriveChild(accountIndex, hardened: true)
      .deriveChild(2, hardened: false)
      .deriveChild(0, hardened: false);
  
  return StakeKeyPair(
    privateKey: stakeKey.toBytes(),
    publicKey: stakeKey.toPublic().toBytes(),
    stakeCredential: blake2b_224(stakeKey.toPublic().toBytes()),
    stakeAddress: encodeStakeAddress(stakeCredential, network),
  );
}
```

### 3.4 交易体 CBOR 结构

```
transaction_body = {
  0: inputs,              // Set<transaction_input>
  1: outputs,             // Set<transaction_output>
  2: fee,                 // coin
  ? 4: certificates,      // Set<certificate>
  ? 5: withdrawals,       // Map<reward_account, coin>
}

certificate 格式：
  stake_registration:   [0, stake_credential]
  stake_deregistration: [1, stake_credential]
  stake_delegation:     [2, stake_credential, pool_keyhash]
```

---

## 4. 观察钱包端设计（coldwallet-watch）

### 4.1 StakingScreen UI

**入口**：HomeScreen 加 Stake 按钮（与 Send/Receive 并列）

**页面布局**：
```
┌─────────────────────────────┐
│ Stake Address               │
│ stake_test1qz...  [复制]    │
├─────────────────────────────┤
│ 质押状态                    │
│ 状态：未注册 / 已委托 pool1...│
│ 累计奖励：2.5 ADA           │
├─────────────────────────────┤
│ [Delegate]  [Withdraw]      │
│ [Deregister]                │
└─────────────────────────────┘
```

**操作按钮行为**：

| 按钮 | 行为 | 条件 |
|------|------|------|
| Delegate | 首次 = registration + delegation，后续 = re-delegation | 始终可用 |
| Withdraw rewards | 提取奖励到 payment address | reward > 0 |
| Deregister | 解除质押，回收 2 ADA deposit | 已注册 |

### 4.2 StakeTransactionBuilder

```dart
class StakeTransactionBuilder {
  final BlockfrostService _blockfrost;
  
  /// 构建 delegation 交易（首次自动合并 registration）
  Future<ColdExport> buildDelegate({
    required String stakeAddress,
    required String poolId,
    required String paymentAddress,
    required bool isRegistered,
  }) async {
    // 1. 查询 UTxO（payment address）
    // 2. 选择 inputs（覆盖 fee + deposit 2 ADA if !isRegistered）
    // 3. 构建 certificates:
    //    - isRegistered=false: [stake_registration, stake_delegation]
    //    - isRegistered=true: [stake_delegation]
    // 4. 构建 outputs（change）
    // 5. 计算 fee
    // 6. 组装 CBOR
    // 7. 返回 ColdExport{txCbor, certificates, stakeKeyPath}
  }
  
  /// 构建 reward withdrawal
  Future<ColdExport> buildWithdrawReward({
    required String stakeAddress,
    required String paymentAddress,
    required int rewardAmount,
  }) async {
    // 1. 查询 UTxO
    // 2. 构建 withdrawals: {reward_address: rewardAmount}
    // 3. 构建 outputs（change = reward - fee）
    // 4. 计算 fee
    // 5. 组装 CBOR
  }
  
  /// 构建 deregistration
  Future<ColdExport> buildDeregister({
    required String stakeAddress,
    required String paymentAddress,
  }) async {
    // 1. 查询 UTxO
    // 2. 构建 certificates: [stake_deregistration]
    // 3. 构建 outputs（change + 2 ADA deposit 退还）
    // 4. 计算 fee
    // 5. 组装 CBOR
  }
}
```

### 4.3 Blockfrost API 扩展

| API | 用途 |
|-----|------|
| `GET /pools/{pool_id}` | 验证 pool 存在 + 未退役 |
| `GET /accounts/{stake_address}` | 查询 stake 状态（registered、pool_id、reward balance） |
| `GET /addresses/{address}/utxos` | 查询 UTxO（现有逻辑） |

### 4.4 Add wallet 流程扩展

**现有流程**：
```
冷钱包显示 payment address QR
→ 观察钱包扫码导入 payment address
```

**扩展后**：
```
冷钱包显示合并 QR:
{
  "paymentAddress": "addr_test1qz...",
  "stakeAddress": "stake_test1qz..."
}
→ 观察钱包扫码一次导入两个地址
→ watch_wallet 模型加 stakeAddress 字段
```

---

## 5. 冷钱包端设计（coldwallet-app）

### 5.1 CardanoAdapter 签名逻辑扩展

```dart
@override
Future<SignResult> signTransaction(String mnemonic, ColdExport export, ChainConfig config) async {
  // 1. 派生 payment key（现有逻辑）
  final paymentKey = await _derivePaymentKey(mnemonic);
  
  // 2. 解析交易体 CBOR
  final tx = CardanoTransaction.deserializeFromHex(export.txCbor);
  
  // 3. 生成 payment key witness（现有逻辑）
  final paymentWitness = await _signWithPaymentKey(paymentKey, tx);
  
  // 4. 如果有 certificates 或 withdrawals → 需要 stake key witness（新增）
  VkeyWitness? stakeWitness;
  if (export.certificates != null || export.withdrawments != null) {
    final stakeKey = await walletService.deriveStakeKey(mnemonic);
    
    // 验证 stake credential 匹配
    final expectedCredential = export.certificates?.first.stakeCredential 
        ?? _extractCredentialFromWithdrawals(export.withdrawments);
    if (stakeKey.stakeCredential != expectedCredential) {
      throw StakeKeyMismatchException();
    }
    
    stakeWitness = await _signWithStakeKey(stakeKey, tx);
  }
  
  // 5. 组装已签名交易（合并 witnesses）
  final signedTx = tx.copyWithAdditionalSignatures({
    if (paymentWitness != null) paymentWitness,
    if (stakeWitness != null) stakeWitness,
  });
  
  return SignResult(signedTxHex: signedTx.serializeHexString(), txHash: ...);
}
```

### 5.2 HomeScreen 显示 stake address

- 在 payment address 下拉列表下方显示 stake address
- 提供复制按钮
- 用于 add wallet 时生成合并 QR

---

## 6. 错误处理

| 场景 | 触发条件 | 处理方式 |
|------|----------|----------|
| Pool 不存在 | Blockfrost 404 | 提示"Pool ID 不存在" |
| Pool 已退役 | `retiring_epoch` 不为 null | 提示"Pool 已退役，请选择其他" |
| Pool ID 格式错误 | 不以 `pool1` 开头或 Bech32 校验失败 | 提示格式错误 |
| 重复 registration | 链上已注册但尝试再次注册 | 自动检测，只发 delegation |
| Reward = 0 | 用户尝试 withdraw | 按钮禁用，提示"无奖励可提取" |
| 未注册就 deregister | stake key 未注册 | 按钮禁用 |
| 余额不足 | delegation 需要 deposit 2 ADA + fee | 提示"余额不足，需要至少 X ADA" |
| Blockfrost API 错误 | 超时/5xx | 提示"网络错误，请稍后重试" |
| Stake credential 不匹配 | JSON 里的 credential 与本地派生不一致 | 提示"Stake key 不匹配，请确认使用正确的钱包" |

---

## 7. 测试计划

### 7.1 单元测试（TDD）

| 文件 | 测试内容 |
|------|----------|
| `stake_key_test.dart` | stake key 派生（path m/1852'/1815'/0'/2/0）、stake credential 计算 |
| `certificate_test.dart` | Certificate 序列化/反序列化（3 种类型） |
| `cold_export_test.dart` | ColdExport 扩展字段序列化、向后兼容（无新字段时默认为 null） |
| `cardano_adapter_stake_test.dart` | CardanoAdapter stake witness 签名（有/无 certificates） |
| `stake_transaction_builder_test.dart` | StakeTransactionBuilder 构建 CBOR（delegate/withdraw/deregister） |

### 7.2 集成测试

| 场景 | 验证点 |
|------|--------|
| 完整 delegation 流程 | 构建 → 签名 → CBOR 正确性 |
| Reward withdrawal 流程 | withdrawals 字段正确 |
| Deregistration 流程 | deposit 退还逻辑 |
| Add wallet 扩展 | 导入 payment + stake 两个地址 |

### 7.3 端到端测试（preview testnet，手动验证）

1. 实际质押 2 ADA 到某个 pool
2. 等待一个 epoch，验证 reward 累积
3. 提取 reward
4. 解除质押，验证 2 ADA 退回

---

## 8. 文件变更清单

### 8.1 coldwallet-app

| 文件 | 改动 |
|------|------|
| `models/certificate.dart` | 新建 Certificate 模型 |
| `models/cold_export.dart` | 加 `certificates`、`withdrawals`、`stakeKeyPath` |
| `services/wallet_service.dart` | 加 `deriveStakeKey()` |
| `services/adapters/cardano_adapter.dart` | 加 stake key witness 签名 |
| `screens/home_screen.dart` | 显示 stake address |

### 8.2 coldwallet-watch

| 文件 | 改动 |
|------|------|
| `screens/staking_screen.dart` | 新建质押 UI |
| `screens/home_screen.dart` | 加 Stake 按钮 |
| `screens/add_wallet_screen.dart` | 扩展导入 stake address |
| `services/stake_transaction_builder.dart` | 新建构建质押交易 |
| `services/blockfrost_service.dart` | 加 pool/stake 状态查询 |
| `models/watch_wallet.dart` | 加 `stakeAddress` 字段 |

### 8.3 文档

| 文件 | 改动 |
|------|------|
| `PROTOCOL.md` | 更新 ColdExport/ColdImport 协议定义，加 certificates/withdrawals 字段 |

---

## 9. YAGNI（不实现）

- Stake pool 列表选择（手动输入 pool ID 足够）
- 多 stake key 支持（只用 account 0）
- Stake pool metadata 展示（只显示 pool ID）
- 自动 re-delegation（用户手动操作）
- Staking 历史记录

---

## 10. 向后兼容

- Payment 交易：`certificates = null, withdrawals = null` → 走现有逻辑，无 stake witness
- Stake 交易：有 certificates/withdrawments → 自动加 stake witness
- `fromJson` 兼容旧版 JSON（无新字段时默认为 null）
- 观察钱包端旧 wallet 模型无 stakeAddress → 提示用户重新 add wallet
