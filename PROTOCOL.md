# 冷热钱包通信协议

本文档定义 coldwallet-app（离线冷钱包）与 coldwallet-watch（联网观察钱包）之间的数据交换格式。

## 概述

两端通过 JSON 格式交换数据，传输方式支持：

- **二维码**：适合小数据量的快速传输
- **剪贴板复制/粘贴**：适合无法扫码或二维码容量不足的场景

## 完整交易流程

```
┌─────────────────┐                          ┌─────────────────┐
│  coldwallet-     │                          │  coldwallet-     │
│  watch（联网端）  │                          │  app（离线端）    │
└────────┬────────┘                          └────────┬────────┘
         │                                            │
    1. 构建未签名交易                                   │
         │                                            │
    2. 导出 ColdExport ────── JSON ──────────→ 3. 导入 ColdExport
         │                                            │
         │                                       4. 用户确认摘要
         │                                       5. PIN 验证
         │                                       6. 离线签名
         │                                            │
    8. 导入 ColdImport ←──── JSON ──────────  7. 导出 ColdImport
         │                                            │
    9. 提交到链上                                      │
         │                                            │
```

## 数据结构

### ColdExport — 未签名交易（热端 → 冷端）

由 coldwallet-watch 构建，传递给 coldwallet-app 进行离线签名。

```json
{
  "version": 1,
  "type": "unsigned-tx",
  "network": "preview",
  "txCbor": "<未签名交易的 CBOR hex 编码>",
  "summary": {
    "fromAddress": "addr_test1qz...",
    "toAddress": "addr_test1qy...",
    "assets": [
      {
        "unit": "lovelace",
        "quantity": "5000000",
        "displayName": null
      }
    ],
    "fee": "172000"
  }
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `version` | `int` | 是 | 协议版本号，当前为 `1` |
| `type` | `String` | 是 | 固定为 `"unsigned-tx"` |
| `network` | `String` | 是 | 网络标识：`"mainnet"` / `"testnet"` / `"preview"` |
| `txCbor` | `String` | 是 | 未签名交易体的 CBOR hex 编码 |
| `summary` | `TxSummary` | 是 | 交易摘要，供冷端用户确认 |
| `certificates` | `Certificate[]?` | 否 | 质押证书列表（仅质押交易） |
| `withdrawals` | `Map<String, int>?` | 否 | 奖励提取：stake_address → lovelace 数量（仅质押交易） |
| `stakeKeyPath` | `String?` | 否 | stake key 派生路径（仅质押交易，如 `m/1852'/1815'/0'/2/0`） |

### TxSummary — 交易摘要

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `fromAddress` | `String` | 是 | 发送方 bech32 地址 |
| `toAddress` | `String` | 是 | 接收方 bech32 地址 |
| `assets` | `AssetAmount[]` | 是 | 转账资产列表（至少 1 项） |
| `fee` | `String` | 是 | 手续费（lovelace 字符串） |
| `deposit` | `String` | 否 | 质押押金（lovelace 字符串）。首次 stake registration 时为 `2000000`，stake deregistration 时为 `-2000000`（退回押金），其他情况省略 |

### AssetAmount — 单个资产

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `unit` | `String` | 是 | ADA 为 `"lovelace"`，原生代币为 policyId+assetName hex |
| `quantity` | `String` | 是 | 数量（最小单位，字符串表示） |
| `displayName` | `String?` | 否 | 可选的显示名称 |

### Certificate — 质押/治理证书

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `type` | `String` | 是 | 证书类型：`stakeRegistration` / `stakeDelegation` / `stakeDeregistration` / `voteDelegation` |
| `stakeCredential` | `String` | 是 | blake2b_224(stake public key)，28 字节 hex 编码 |
| `poolKeyHash` | `String?` | 否 | 委托目标 pool key hash（仅 `stakeDelegation`） |
| `dRepType` | `String?` | 否 | DRep 委托目标类型：`abstain` / `noConfidence` / `keyHash` / `scriptHash`（仅 `voteDelegation`） |
| `dRepHash` | `String?` | 否 | DRep key/script hash，28 字节 hex（仅 `dRepType` 为 `keyHash` / `scriptHash`） |

```json
{
  "type": "stakeDelegation",
  "stakeCredential": "a1b2c3d4e5f6...",
  "poolKeyHash": "pool1abc..."
}
```

```json
{
  "type": "voteDelegation",
  "stakeCredential": "a1b2c3d4e5f6...",
  "dRepType": "abstain"
}
```

> DRep 弃权委托证书随委托交易自动附带（见 ADR 0004）：Conway 时代提取奖励
> 要求 stake key 在提取交易**之前**就已弃权（或委托 DRep），ledger 对 withdrawal
> 的检查用证书应用前的账户状态快照，因此弃权证书不能与奖励提取同笔交易。

### 质押交易示例

委托交易（注册 + 委托 + DRep 弃权合并）：

```json
{
  "version": 1,
  "type": "unsigned-tx",
  "network": "preview",
  "txCbor": "<CBOR hex>",
  "summary": {
    "fromAddress": "addr_test1qz...",
    "toAddress": "addr_test1qz...",
    "assets": [{ "unit": "lovelace", "quantity": "0" }],
    "fee": "180000",
    "deposit": "2000000"
  },
  "certificates": [
    { "type": "stakeRegistration", "stakeCredential": "a1b2c3..." },
    { "type": "stakeDelegation", "stakeCredential": "a1b2c3...", "poolKeyHash": "pool1abc..." },
    { "type": "voteDelegation", "stakeCredential": "a1b2c3...", "dRepType": "abstain" }
  ],
  "stakeKeyPath": "m/1852'/1815'/0'/2/0"
}
```

提取奖励交易：

```json
{
  "version": 1,
  "type": "unsigned-tx",
  "network": "preview",
  "txCbor": "<CBOR hex>",
  "summary": {
    "fromAddress": "addr_test1qz...",
    "toAddress": "addr_test1qz...",
    "assets": [{ "unit": "lovelace", "quantity": "0" }],
    "fee": "175000"
  },
  "withdrawals": {
    "stake_test1u...": 5000000
  },
  "stakeKeyPath": "m/1852'/1815'/0'/2/0"
}
```

### ColdImport — 已签名交易（冷端 → 热端）

由 coldwallet-app 签名后导出，传递给 coldwallet-watch 提交到链上。

```json
{
  "version": 1,
  "type": "signed-tx",
  "txCbor": "<已签名交易的 CBOR hex 编码>",
  "txHash": "<交易哈希 hex>"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `version` | `int` | 是 | 协议版本号，当前为 `1` |
| `type` | `String` | 是 | 固定为 `"signed-tx"` |
| `txCbor` | `String` | 是 | 已签名交易的完整 CBOR hex 编码 |
| `txHash` | `String` | 是 | 交易哈希（blake2b_256 of tx body） |

## 地址导入格式

观察钱包添加钱包时，支持扫描二维码同时导入支付地址和 stake address。

### 合并地址 QR

```json
{
  "paymentAddress": "addr_test1qz...",
  "stakeAddress": "stake_test1u..."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `paymentAddress` | `String` | 是 | Cardano 支付地址（bech32 格式） |
| `stakeAddress` | `String` | 是 | Cardano stake address（bech32 格式） |

coldwallet-app 导出时生成的 QR 即为此格式，coldwallet-watch 扫码后自动解析两个字段。

## 传输方式

### 二维码传输

- ColdExport → 冷端：coldwallet-watch 将 JSON 编码为二维码，coldwallet-app 扫码读取
- ColdImport → 热端：coldwallet-app 将 JSON 编码为二维码，coldwallet-watch 扫码读取

> 注意：当 CBOR 数据较大时，二维码可能过于密集，此时建议使用剪贴板复制完整 JSON 进行传输。

### 剪贴板传输

- 导出端将 JSON 完整复制到系统剪贴板
- 导入端从剪贴板读取并解析 JSON
- 两端均提供明确的「复制 JSON」和「粘贴 JSON」按钮

## 版本兼容

- `version` 字段用于未来协议升级
- 接收端应检查 `version` 是否支持，不支持时提示用户升级 App
- `type` 字段用于区分数据类型，接收端应校验 `type` 是否符合预期

## 源码位置

| 数据结构 | 定义位置 |
|----------|----------|
| ColdExport / ColdImport | `coldwallet-protocol/lib/cardano/` |
| EthColdExport / EthColdImport | `coldwallet-protocol/lib/evm/` |
| Certificate / CertificateType / DRepType | `coldwallet-protocol/lib/cardano/certificate.dart` |
| AppConfig / ChainConfig / ChainRegistry | `coldwallet-protocol/lib/` |

> 两端 App 均通过 `package:coldwallet_protocol` 共享同一套模型定义，修改时只需更新
> coldwallet-protocol 并同步本文档。
