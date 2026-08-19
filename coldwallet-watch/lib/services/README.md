# services 模块

观察钱包的业务逻辑层。封装了区块链数据查询、本地存储、钱包管理和交易构建等核心功能。所有 services 都是无状态的，通过构造函数注入依赖。

## 文件清单

| 文件 | 主要类 | 功能说明 |
|------|--------|----------|
| asset_service.dart | AssetService | 资产查询，通过 Blockfrost 获取地址余额并结合用户启用配置返回资产列表 |
| blockfrost_service.dart | BlockfrostService, BlockfrostEndpoint | Blockfrost API 封装，提供 UTxO、余额、区块、协议参数查询和交易提交 |
| storage_service.dart | StorageService | 本地存储，SharedPreferences 存钱包列表，SecureStorage 存 API Key |
| stake_transaction_builder.dart | StakeTransactionBuilder | 质押交易构建，支持委托、提取奖励、解除注册三种操作，迭代计算手续费 |
| tx_builder_service.dart | TxBuilderService | 交易构建，使用 cardano_dart_types 构建 ADA 转账的未签名交易，迭代计算手续费 |
| wallet_service.dart | WalletService | 钱包管理，提供只读钱包的增删改查、当前钱包切换和地址格式验证 |

## 公开方法

### WalletService

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `getWallets()` | `Future<List<WatchWallet>>` | 获取所有钱包列表 |
| `getCurrentWallet()` | `Future<WatchWallet?>` | 获取当前钱包（无则自动选第一个） |
| `setCurrentWallet(id)` | `Future<void>` | 切换当前钱包 |
| `addWallet(name, address, network, stakeAddress?)` | `Future<WatchWallet>` | 添加新钱包并保存 |
| `deleteWallet(id)` | `Future<void>` | 删除钱包（自动切换当前） |
| `updateWallet(wallet)` | `Future<void>` | 更新钱包信息 |
| `validateAddress(address)` | `bool` | 校验 Cardano bech32 地址格式 |

### BlockfrostService

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `getAddressUtxos(address)` | `Future<List<Map>>` | 查询地址所有 UTxO |
| `getAddressBalance(address)` | `Future<Map>` | 查询地址资产余额 |
| `getLatestBlock()` | `Future<Map>` | 获取最新区块（含 slot） |
| `getProtocolParams()` | `Future<Map>` | 获取协议参数（手续费系数等） |
| `submitTx(txBytes)` | `Future<String>` | 提交已签名交易，返回交易哈希 |
| `getPoolInfo(poolId)` | `Future<Map>` | 查询 stake pool 信息 |
| `isPoolRetired(poolId)` | `Future<bool>` | 检查 pool 是否已退役 |
| `getStakeAccountInfo(stakeAddress)` | `Future<Map>` | 查询 stake account 信息（状态、委托池、可提取奖励） |

### AssetService

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `loadBalances(address, walletId)` | `Future<List<AssetBalance>>` | 加载地址资产余额，结合用户启用配置 |

### StakeTransactionBuilder

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `buildDelegate(fromAddress, stakeAddress, poolIdBech32, network, isStakeRegistered)` | `Future<ColdExport>` | 构建委托交易（自动注册 stake key + 委托） |
| `buildWithdrawReward(fromAddress, stakeAddress, withdrawableAmount, network)` | `Future<ColdExport>` | 构建提取奖励交易 |
| `buildDeregister(fromAddress, stakeAddress, network)` | `Future<ColdExport>` | 构建解除 stake key 注册交易 |

### TxBuilderService

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `buildTransferTx(fromAddress, toAddress, assets, network)` | `Future<ColdExport>` | 构建 ADA 转账未签名交易（MVP 仅 lovelace），迭代估算手续费 |

### StorageService

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `create()` | `Future<StorageService>` | 工厂方法，初始化 SharedPreferences 和 SecureStorage |
| `loadWallets()` / `saveWallets(wallets)` | — | 钱包列表读写（SharedPreferences） |
| `getCurrentWalletId()` / `setCurrentWalletId(id)` | — | 当前钱包 ID |
| `getCurrentNetwork()` / `setCurrentNetwork(network)` | — | 网络设置（固定 preview） |
| `getBlockfrostApiKey()` / `setBlockfrostApiKey(key)` / `deleteBlockfrostApiKey()` | — | API Key 管理（SecureStorage） |
| `getEnabledAssets(walletId)` / `setEnabledAssets(walletId, units)` | — | 用户启用的资产列表 |

## 依赖关系

- **内部依赖**：
  - `models/` — WatchWallet、AssetBalance、ColdExport
- **外部依赖**：
  - `http` — HTTP 请求（Blockfrost API）
  - `shared_preferences` — 明文本地存储
  - `flutter_secure_storage` — 加密安全存储
  - `cardano_dart_types` — Cardano 交易类型定义

## 服务调用关系

```
screens/ → WalletService → StorageService
screens/ → AssetService → BlockfrostService + StorageService
screens/ → TxBuilderService → BlockfrostService
screens/ → StakeTransactionBuilder → BlockfrostService
screens/ → BlockfrostService（直接调用 submitTx / getPoolInfo / getStakeAccountInfo）
```

## 存储 Key 规划

| Key | 内容 | 存储方式 |
|-----|------|---------|
| `watch_wallets` | 只读钱包列表 JSON | SharedPreferences |
| `current_wallet_id` | 当前选中钱包 ID | SharedPreferences |
| `blockfrost_api_key` | Blockfrost API Key | SecureStorage |
| `enabled_assets_{walletId}` | 用户启用的资产 unit 列表 | SharedPreferences |

## 常见修改指引

| 我想... | 修改文件 |
|---------|---------|
| 切换区块链 API 提供商 | blockfrost_service.dart — 替换 API 调用逻辑 |
| 添加新的 API 查询方法 | blockfrost_service.dart — 添加新的 Future 方法 |
| 修改钱包存储格式 | storage_service.dart — 修改 key 和序列化方式 |
| 支持多资产转账 | tx_builder_service.dart — 修改 buildTransferTx 和 _buildOutputs |
| 修改地址验证规则 | wallet_service.dart — 修改 validateAddress 方法 |
| 添加新的存储配置项 | storage_service.dart — 添加新的 key 和 getter/setter |
| 修改手续费计算逻辑 | tx_builder_service.dart — 修改迭代估算循环 |
