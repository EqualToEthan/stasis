# models 模块

冷钱包的数据模型层。定义了钱包元数据（不含敏感信息）、冷热钱包之间传递的交易数据结构，以及多链配置和签名结果等通用模型。WalletInfo 与助记词分离存储，助记词按 ID 独立保存在安全存储中。

## 文件清单

| 文件 | 主要类 | 功能说明 |
|------|--------|----------|
| cold_export.dart | ColdExport, TxSummary, AssetAmount | Cardano 联网端导出的未签名交易数据，包含 CBOR、摘要和资产列表 |
| cold_import.dart | ColdImport | Cardano 离线签名后导出的已签名交易数据，包含 CBOR 和交易哈希 |
| wallet_info.dart | WalletInfo, WalletListCodec | 钱包元数据模型（ID、名称、创建时间），与助记词分离存储 |
| chain_config.dart | ChainConfig | 链配置模型，描述链 ID、链族、名称、网络和 EVM chain ID |
| sign_result.dart | SignResult | 通用签名结果，包含已签名交易 hex 和交易哈希 |
| eth_cold_export.dart | EthColdExport, EvmTxSummary | EVM 链未签名交易数据，包含 RLP hex、chainId 和摘要 |
| eth_cold_import.dart | EthColdImport | EVM 链已签名交易数据，包含签名后的 RLP hex 和交易哈希 |

## 数据模型详情

### WalletInfo — 钱包元数据

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 16 字符随机 ID（64 bits） |
| `name` | `String` | 用户自定义钱包名称 |
| `createdAt` | `DateTime` | 创建时间 |

- `WalletInfo.create(name)` — 工厂方法，自动生成 ID 和时间戳
- `WalletInfo.fromJson(json)` / `toJson()` — JSON 序列化
- `WalletListCodec.encode(wallets)` / `decode(json)` — 钱包列表批量序列化

### ColdExport — 未签名交易（热端 → 冷端）

| 字段 | 类型 | 说明 |
|------|------|------|
| `version` | `int` | 协议版本号 |
| `type` | `String` | 数据类型标识（`unsigned-tx`） |
| `network` | `String` | 网络标识（`mainnet` / `testnet`） |
| `txCbor` | `String` | 未签名交易的 CBOR hex 编码 |
| `summary` | `TxSummary` | 交易摘要（供用户确认） |

### TxSummary — 交易摘要

| 字段 | 类型 | 说明 |
|------|------|------|
| `fromAddress` | `String` | 发送方地址 |
| `toAddress` | `String` | 接收方地址 |
| `assets` | `List<AssetAmount>` | 转账资产列表 |
| `fee` | `String` | 手续费（lovelace） |

### AssetAmount — 单个资产

| 字段 | 类型 | 说明 |
|------|------|------|
| `unit` | `String` | 资产标识（`lovelace` 或 policyId+assetName hex） |
| `quantity` | `String` | 数量（最小单位） |
| `displayName` | `String?` | 可选的显示名称 |
| `displayLabel` | `String`（getter） | 优先使用 displayName，否则显示 unit |

### ColdImport — 已签名交易（冷端 → 热端）

| 字段 | 类型 | 说明 |
|------|------|------|
| `version` | `int` | 协议版本号 |
| `type` | `String` | 数据类型标识（`signed-tx`） |
| `txCbor` | `String` | 已签名交易的 CBOR hex 编码 |
| `txHash` | `String` | 交易哈希（blake2b_256） |

### ChainConfig — 链配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `chainId` | `String` | 唯一标识，如 `cardano-preview`、`evm-11155111` |
| `chainFamily` | `String` | 链族标识：`cardano`、`evm`、`bitcoin` |
| `name` | `String` | 显示名称，如 `Ethereum Sepolia` |
| `network` | `String` | 网络标识，如 `sepolia`、`preview` |
| `evmChainId` | `int?` | EVM 链专用链 ID（如 11155111），非 EVM 链为 null |

### SignResult — 签名结果

| 字段 | 类型 | 说明 |
|------|------|------|
| `signedTxHex` | `String` | 已签名交易的 hex 编码（CBOR / RLP 等） |
| `txHash` | `String` | 交易哈希 hex |
| `version` | `int` | 协议版本号（默认 1） |

### EthColdExport — EVM 未签名交易（联网端 → 冷端）

| 字段 | 类型 | 说明 |
|------|------|------|
| `version` | `int` | 协议版本号 |
| `type` | `String` | 数据类型标识（`unsigned-tx`） |
| `chainId` | `String` | 链 ID，如 `evm-11155111` |
| `rawTxHex` | `String` | RLP 编码的未签名交易 hex |
| `summary` | `EvmTxSummary` | 交易摘要（供用户确认） |

### EvmTxSummary — EVM 交易摘要

| 字段 | 类型 | 说明 |
|------|------|------|
| `fromAddress` | `String` | 发送方地址 |
| `toAddress` | `String` | 接收方地址 |
| `value` | `String` | 转账金额（wei） |
| `fee` | `String` | 预估 Gas 费用（wei） |
| `nonce` | `int` | 交易 nonce |

### EthColdImport — EVM 已签名交易（冷端 → 联网端）

| 字段 | 类型 | 说明 |
|------|------|------|
| `version` | `int` | 协议版本号 |
| `type` | `String` | 数据类型标识（`signed-tx`） |
| `rawTxHex` | `String` | 签名后的完整 RLP 交易 hex |
| `txHash` | `String` | 交易哈希（keccak256） |

## 依赖关系

- **内部依赖**：无（models 是最底层，被 services 和 screens 依赖）
- **外部依赖**：`dart:convert`（JSON）、`dart:math`（随机 ID 生成）

## 常见修改指引

| 我想... | 修改文件 |
|---------|---------|
| 给钱包添加新属性（如备注、颜色） | wallet_info.dart — 添加字段 + toJson/fromJson |
| 修改交易摘要展示的内容 | cold_export.dart — 修改 TxSummary 类 |
| 修改钱包 ID 生成策略 | wallet_info.dart — 修改 _generateId 方法 |
| 修改冷热钱包传输格式 | cold_export.dart / cold_import.dart — 同步修改两端模型 |
| 添加新的 EVM 链支持 | chain_config.dart 添加配置 + chain_registry.dart 注册 |
| 修改 EVM 交易摘要字段 | eth_cold_export.dart — 修改 EvmTxSummary 类 |
| 修改签名结果格式 | sign_result.dart — 修改 SignResult 类 |
