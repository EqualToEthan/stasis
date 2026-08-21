# 冷热钱包通信协议

本文档定义 coldwallet-app（离线冷钱包）与 coldwallet-watch（联网观察钱包）之间的数据交换格式。

## 概述

两端通过 JSON 格式交换数据，传输方式支持：

- **二维码**：适合小数据量的快速传输
- **文件导出/导入**：适合大数据量或无摄像头场景

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
| `deposit` | `String` | 否 | 质押押金（lovelace 字符串）。首次 stake registration 时为 `2000000`，其他情况省略 |

### AssetAmount — 单个资产

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `unit` | `String` | 是 | ADA 为 `"lovelace"`，原生代币为 policyId+assetName hex |
| `quantity` | `String` | 是 | 数量（最小单位，字符串表示） |
| `displayName` | `String?` | 否 | 可选的显示名称 |

### Certificate — 质押证书

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `type` | `String` | 是 | 证书类型：`stakeRegistration` / `stakeDelegation` / `stakeDeregistration` |
| `stakeCredential` | `String` | 是 | blake2b_224(stake public key)，28 字节 hex 编码 |
| `poolKeyHash` | `String?` | 否 | 委托目标 pool key hash（仅 `stakeDelegation`） |

```json
{
  "type": "stakeDelegation",
  "stakeCredential": "a1b2c3d4e5f6...",
  "poolKeyHash": "pool1abc..."
}
```

### 质押交易示例

委托交易（注册 + 委托合并）：

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
    { "type": "stakeDelegation", "stakeCredential": "a1b2c3...", "poolKeyHash": "pool1abc..." }
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

> 注意：当 CBOR 数据较大时，二维码可能过于密集，此时建议使用文件传输。

### 文件传输

- 导出端将 JSON 写入 `.json` 文件
- 导入端通过文件选择器读取并解析 JSON
- 文件命名建议：`cold-export-{timestamp}.json` / `cold-import-{timestamp}.json`

## 版本兼容

- `version` 字段用于未来协议升级
- 接收端应检查 `version` 是否支持，不支持时提示用户升级 App
- `type` 字段用于区分数据类型，接收端应校验 `type` 是否符合预期

## 源码位置

| 数据结构 | coldwallet-app | coldwallet-watch |
|----------|---------------|-----------------|
| ColdExport | `lib/models/cold_export.dart` | `lib/models/cold_export.dart` |
| ColdImport | `lib/models/cold_import.dart` | `lib/models/cold_import.dart` |
| Certificate | `lib/models/certificate.dart` | `lib/models/certificate.dart` |

> 两端的模型定义保持一致，修改时需要同步更新。
