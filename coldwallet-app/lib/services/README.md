# services 模块

冷钱包的核心业务逻辑层。封装了安全存储、钱包密钥管理、多链地址派生和交易签名等关键功能。通过链适配器模式支持 Cardano、EVM（Ethereum/BSC/Arbitrum/Polygon/Base）等多链族。完全离线运行，所有敏感数据通过 Android Keystore 加密存储。

## 文件清单

| 文件 | 主要类 | 功能说明 |
|------|--------|----------|
| secure_storage_service.dart | SecureStorageService | 安全存储，通过 Android Keystore 加密存储助记词、PIN 和钱包列表 |
| transaction_service.dart | TransactionService | 交易签名，支持 Cardano（CBOR）和 EVM（RLP）多链签名路由 |
| wallet_service.dart | WalletService | 钱包服务，助记词生成/验证、HD 钱包创建、多链地址派生、多钱包管理和 PIN 管理 |
| chain_registry.dart | ChainRegistry | 链注册中心，管理所有链配置，提供适配器实例查找 |
| adapters/chain_adapter.dart | ChainAdapter | 链适配器抽象接口，定义地址派生、交易解析和签名方法 |
| adapters/cardano_adapter.dart | CardanoAdapter | Cardano 适配器，CIP-1852 地址派生 + Ed25519 签名 |
| adapters/evm_adapter.dart | EvmAdapter | EVM 适配器，BIP-44 地址派生 + EIP-155/EIP-1559 签名 |

## 公开方法

### WalletService

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `generateMnemonic()` | `List<String>` | 生成 24 词助记词（安全随机源） |
| `mnemonicFromDiceBits(bits)` | `String` | 从 256 个骰子结果生成助记词 |
| `validateMnemonic(mnemonic)` | `bool` | 校验助记词是否有效 |
| `createWallet(mnemonic, {testnet})` | `Future<CardanoWallet>` | 从助记词创建 HD 钱包 |
| `deriveAddress(mnemonic, {testnet})` | `Future<String>` | 派生 Cardano CIP-1852 地址（m/1852'/1815'/0'/0/0） |
| `deriveAddressForChain(mnemonic, config)` | `Future<String>` | 派生指定链的地址（通过 ChainRegistry 路由） |
| `deriveAllAddresses(mnemonic)` | `Future<Map<String, String>>` | 派生所有链的地址，返回 `Map<chainId, address>` |
| `getWallets()` | `Future<List<WalletInfo>>` | 获取所有钱包列表 |
| `hasWallets()` | `Future<bool>` | 是否已有钱包 |
| `canAddWallet()` | `Future<bool>` | 是否还能添加钱包（上限 5 个） |
| `getCurrentWallet()` | `Future<WalletInfo?>` | 获取当前选中钱包 |
| `loadCurrentMnemonic()` | `Future<String?>` | 加载当前钱包的助记词 |
| `switchWallet(walletId)` | `Future<void>` | 切换当前钱包 |
| `addWallet(name, mnemonic)` | `Future<WalletInfo>` | 添加新钱包并设为当前 |
| `deleteWallet(walletId)` | `Future<void>` | 删除钱包（自动切换当前） |
| `resetAllWallets()` | `Future<void>` | 清除所有钱包数据（PIN 保留） |
| `factoryReset()` | `Future<void>` | 清除全部存储（含 PIN） |
| `savePin(pin)` / `verifyPin(pin)` / `hasPin()` | — | PIN 管理 |
| `getNetwork()` / `setNetwork(network)` / `isTestnet()` | — | 网络设置 |

### TransactionService

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `parseColdExport(jsonString)` | `ColdExport` | 从 JSON 字符串解析 Cardano 未签名交易数据 |
| `signTransaction(coldExport)` | `Future<ColdImport>` | 用当前钱包私钥签名 Cardano 交易，返回已签名数据 |
| `signForChain(rawJson)` | `Future<Map<String, dynamic>>` | 多链统一签名入口，根据 chainId 路由到对应适配器 |

### SecureStorageService

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `loadWalletList()` / `saveWalletList(wallets)` | — | 钱包列表读写 |
| `saveMnemonic(id, mnemonic)` / `readMnemonic(id)` / `deleteMnemonic(id)` | — | 按钱包 ID 隔离的助记词读写 |
| `setCurrentWalletId(id)` / `getCurrentWalletId()` | — | 当前选中钱包 ID |
| `setCurrentNetwork(network)` / `getCurrentNetwork()` | — | 全局网络设置 |
| `savePin(pin)` / `verifyPin(pin)` / `hasPin()` | — | PIN 管理（TODO: 改为哈希存储） |
| `clearAll()` | `Future<void>` | 清空所有存储数据 |

## 依赖关系

- **内部依赖**：
  - `models/` — WalletInfo、ColdExport、ColdImport、ChainConfig、SignResult、EthColdExport、EthColdImport
- **外部依赖**：
  - `flutter_secure_storage` — Android Keystore 加密存储
  - `cardano_flutter_sdk` — Cardano HD 钱包创建和交易签名
  - `cardano_dart_types` — Cardano 交易类型定义
  - `web3dart` — EVM 链的私钥管理和交易签名
  - `bip39_plus` — BIP-39 助记词生成和验证
  - `pointycastle` — blake2b 哈希（Cardano）和 HMAC-SHA512（BIP-32 密钥派生）
  - `hex` — 十六进制编码/解码

## 服务调用关系

```
screens/ → WalletService → SecureStorageService（钱包管理）
                         → cardano_flutter_sdk（Cardano 助记词、地址派生）
                         → ChainRegistry → ChainAdapter（多链地址派生）
screens/ → TransactionService → WalletService → SecureStorageService（签名时读取助记词）
                               → ChainRegistry → ChainAdapter（多链签名路由）
                              
                               → cardano_flutter_sdk（Cardano 交易签名）
                              
                               → web3dart（EVM 交易签名）
                              
                               → pointycastle（blake2b 哈希 / HMAC-SHA512）
```

## 存储 Key 规划

| Key | 内容 | 存储方式 |
|-----|------|---------|
| `wallet_list` | 钱包元数据列表 JSON | SecureStorage |
| `wallet_{id}_mnemonic` | 按 ID 隔离的助记词 | SecureStorage |
| `current_wallet_id` | 当前选中钱包 ID | SecureStorage |
| `current_network` | 全局网络 mainnet/testnet | SecureStorage |
| `wallet_pin_hash` | 全局 PIN | SecureStorage |

## 常见修改指引

| 我想... | 修改文件 |
|---------|---------|
| 修改助记词生成方式（如支持 12 词） | wallet_service.dart — 修改 generateMnemonic 的 wordsCount 参数 |
| 修改 PIN 验证逻辑（如改为哈希） | secure_storage_service.dart — 修改 savePin/verifyPin |
| 添加新的存储配置项 | secure_storage_service.dart — 添加新的 key 和 getter/setter |
| 支持新的交易类型（如质押委托） | transaction_service.dart — 添加新的签名方法 |
| 添加新的 EVM 链 | chain_registry.dart — 在 _configs 中添加 ChainConfig 条目 |
| 添加新的链族（如 Bitcoin） | adapters/ 目录新建适配器 + chain_registry.dart 注册 |
| 修改 EVM 密钥派生路径 | adapters/evm_adapter.dart — 修改 _derivePrivateKey 中的 indices |
| 修改 Cardano 签名逻辑 | adapters/cardano_adapter.dart — 修改 signTransaction 方法 |
| 修改地址派生路径 | wallet_service.dart — 修改 deriveAddress 中的 addressIndex |
| 修改最大钱包数量限制 | wallet_service.dart — 修改 maxWallets 常量 |
| 添加工厂重置功能 | wallet_service.dart — 使用 factoryReset 方法 |
