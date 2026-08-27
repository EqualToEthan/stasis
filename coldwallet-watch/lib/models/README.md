# models 模块

观察钱包的数据模型层。定义了只读钱包、资产余额、以及冷热钱包之间传递的交易数据结构。所有模型都支持 JSON 序列化/反序列化，用于本地存储和二维码/剪贴板传输。

## 文件清单

| 文件 | 主要类 | 功能说明 |
|------|--------|----------|
| asset_balance.dart | AssetBalance | Cardano 资产余额模型，包含资产标识、数量、显示名称和启用状态 |
| evm_asset_balance.dart | EvmAssetBalance | EVM 资产余额模型，支持原生代币（ETH/BNB 等）和 ERC-20 代币 |
| certificate.dart | Certificate, CertificateType | 质押证书模型，描述注册/委托/解除注册操作 |
| cold_export.dart | ColdExport, TxSummary, AssetAmount | 热端导出给冷端的未签名交易数据，包含 CBOR、摘要、资产列表和质押字段 |
| cold_import.dart | ColdImport | 冷端签名后返回给热端的已签名交易数据，包含 CBOR 和交易哈希 |
| watch_wallet.dart | WatchWallet | 只读钱包模型，存储观察地址的名称、地址、链族（cardano/evm）、具体链 ID、网络和创建时间 |

## 数据模型详情

### WatchWallet — 只读钱包

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 基于时间戳的唯一 ID |
| `name` | `String` | 用户自定义钱包名称 |
| `address` | `String` | 观察地址（Cardano bech32 或 EVM hex） |
| `stakeAddress` | `String?` | Cardano stake address（可选，仅 Cardano 链族有效） |
| `chainFamily` | `String` | 链族标识：`'cardano'` 或 `'evm'` |
| `chainId` | `String?` | 具体链 ID（EVM 链需要，如 `sepolia`、`bsc-testnet`） |
| `network` | `String` | 网络标识（`preview`） |
| `createdAt` | `DateTime` | 创建时间 |

- `WatchWallet.create(name, address, chainFamily, network, ...)` — 工厂方法，自动生成 ID
- `WatchWallet.fromJson(json)` / `toJson()` — JSON 序列化（向后兼容：旧数据无 chainFamily 默认 cardano）
- `copyWith(...)` — 不可变更新
- `isCardano` / `isEvm` — 链族判断 getter

### AssetBalance — 资产余额

| 字段 | 类型 | 说明 |
|------|------|------|
| `unit` | `String` | 资产标识（`lovelace` 或 policyId+assetName hex） |
| `quantity` | `String` | 数量（最小单位） |
| `displayName` | `String?` | 显示名称 |
| `isEnabled` | `bool` | 用户是否启用该资产显示 |
| `isAda` | `bool`（getter） | 是否为 ADA（`unit == 'lovelace'`） |

- `AssetBalance.fromJson(json)` / `toJson()` — JSON 序列化
- `copyWith(...)` — 不可变更新

### EvmAssetBalance — EVM 资产余额

| 字段 | 类型 | 说明 |
|------|------|------|
| `contractAddress` | `String?` | ERC-20 合约地址；原生代币为 null |
| `symbol` | `String` | 代币符号，如 ETH、USDT |
| `decimals` | `int` | 小数位 |
| `balanceInWei` | `String` | 以最小单位表示的余额 |

- `isNative` — 是否为原生代币（contractAddress == null）
- `formattedBalance` — 按 decimals 格式化后的人类可读字符串
- `fromJson(json)` / `toJson()` — JSON 序列化
- `copyWith(..., clearContractAddress: true)` — 不可变更新

### ColdExport — 未签名交易（热端 → 冷端）

| 字段 | 类型 | 说明 |
|------|------|------|
| `version` | `int` | 协议版本号（默认 1） |
| `type` | `String` | 数据类型标识（默认 `unsigned-tx`） |
| `network` | `String` | 网络标识 |
| `txCbor` | `String` | 未签名交易的 CBOR hex 编码 |
| `summary` | `TxSummary` | 交易摘要 |
| `certificates` | `List<Certificate>?` | 质押证书列表（仅质押交易） |
| `withdrawals` | `Map<String, int>?` | 奖励提取映射（仅质押交易） |
| `stakeKeyPath` | `String?` | stake key 派生路径（仅质押交易） |

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
| `unit` | `String` | 资产标识 |
| `quantity` | `String` | 数量（最小单位） |
| `displayName` | `String?` | 可选显示名称 |
| `displayLabel` | `String`（getter） | 优先 displayName，否则 unit |

### Certificate — 质押证书

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | `CertificateType` | 证书类型：stakeRegistration / stakeDelegation / stakeDeregistration |
| `stakeCredential` | `String` | blake2b_224(stake public key)，28 字节 hex 编码 |
| `poolKeyHash` | `String?` | 委托目标 pool key hash（仅 delegation） |

### ColdImport — 已签名交易（冷端 → 热端）

| 字段 | 类型 | 说明 |
|------|------|------|
| `version` | `int` | 协议版本号（默认 1） |
| `type` | `String` | 数据类型标识（默认 `signed-tx`） |
| `txCbor` | `String` | 已签名交易的 CBOR hex 编码 |
| `txHash` | `String` | 交易哈希 |

## 依赖关系

- **内部依赖**：无（models 是最底层，被 services 和 screens 依赖）
- **外部依赖**：无纯 Dart 模型，不依赖第三方包

## 常见修改指引

| 我想... | 修改文件 |
|---------|---------|
| 给钱包添加新属性（如标签、图标） | watch_wallet.dart — 添加字段 + toJson/fromJson + copyWith |
| 添加新的链族支持 | watch_wallet.dart — 扩展 chainFamily 枚举值 + 更新校验规则 |
| 修改交易摘要展示的内容 | cold_export.dart — 修改 TxSummary 类 |
| 支持新的资产类型 | asset_balance.dart / evm_asset_balance.dart — 添加字段或新的 getter |
| 调整 EVM 余额展示精度 | evm_asset_balance.dart — 修改 formattedBalance |
| 新增 EVM 代币标准支持 | evm_asset_balance.dart — 扩展字段和序列化 |
| 修改冷热钱包传输格式 | cold_export.dart / cold_import.dart — 同步修改两端的模型 |
