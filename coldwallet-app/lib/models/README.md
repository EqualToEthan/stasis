# models 模块

冷钱包的数据模型层。定义了钱包元数据（不含敏感信息）和冷热钱包之间传递的交易数据结构。WalletInfo 与助记词分离存储，助记词按 ID 独立保存在安全存储中。

## 文件清单

| 文件 | 主要类 | 功能说明 |
|------|--------|----------|
| cold_export.dart | ColdExport, TxSummary, AssetAmount | 联网端导出的未签名交易数据，包含 CBOR、摘要和资产列表 |
| cold_import.dart | ColdImport | 离线签名后导出的已签名交易数据，包含 CBOR 和交易哈希 |
| wallet_info.dart | WalletInfo, WalletListCodec | 钱包元数据模型（ID、名称、创建时间），与助记词分离存储 |

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
