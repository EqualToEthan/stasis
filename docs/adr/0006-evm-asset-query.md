# coldwallet-watch EVM 资产查询

## 背景

coldwallet-watch 当前已支持添加 EVM 观察钱包并识别链族，但 `HomeScreen` 对 EVM 钱包直接跳过余额查询，显示 "EVM 链余额查询暂不支持"。随着产品需要覆盖 Ethereum、BSC、Arbitrum、Polygon、Base 等多条 EVM 链，必须在观察端补齐 EVM 资产余额展示能力。

本次范围限定为：读取型余额查询，不涉及交易构建或签名。

## 决策

1. **资产范围**
   - 原生代币（ETH、BNB、MATIC 等）+ ERC-20 同质化代币。
   - 不包含 NFT（ERC-721 / ERC-1155），后续单独评估。
   - USDT、USDC 及各类 ERC-20 股票/证券型代币，只要符合 ERC-20 标准即可查询。

2. **数据源**
   - 使用公共 JSON-RPC 节点（Ankr、LlamaNodes 等）查询：
     - 原生余额：`eth_getBalance`
     - ERC-20 余额与元数据：`eth_call` 调用 `balanceOf(address)`、`symbol()`、`decimals()`
   - 不引入 Alchemy、Infura、Etherscan 等需要 API key 的服务，降低用户配置门槛。
   - 设置页允许用户覆盖默认 RPC 端点，与 Blockfrost API Key 共用 `StorageService`。

3. **代币发现**
   - 不自动扫描地址历史代币持有记录。
   - 采用手动添加：用户在设置页 "管理 EVM 代币" 输入合约地址，实时校验是否可读。
   - 默认只展示原生代币；用户手动添加的 ERC-20 按链全局保存，同链所有 EVM 钱包共享。

4. **元数据**
   - 合约 `symbol()` / `decimals()` 链上读取。
   - 不显示图标，不调用第三方 token 列表或价格 API。

5. **展示位置**
   - EVM 资产直接展示在 `HomeScreen` 现有资产列表中，替代原来的占位提示。
   - 进入页面自动刷新一次余额；支持下拉手动刷新。

6. **链覆盖**
   - 支持 `ChainRegistry` 中已配置的全部 5 条 EVM 链及其测试网：
     - Ethereum（mainnet / Sepolia）
     - BSC（mainnet / Chapel testnet）
     - Arbitrum（mainnet / Sepolia）
     - Polygon（mainnet / Amoy）
     - Base（mainnet / Sepolia）

7. **数据模型**
   - 新建 `EvmAssetBalance` 模型，字段包括：
     - `contractAddress`：ERC-20 合约地址；原生代币为 `null` 或 sentinel 值。
     - `symbol`：代币符号。
     - `decimals`：小数位。
     - `balanceInWei`：原始余额（wei 单位，字符串）。
   - 不直接复用 Cardano -centric 的 `AssetBalance`，避免字段语义混淆；UI 层统一映射为显示行。

8. **RPC 客户端**
   - 不新增 `web3dart` 依赖。
   - 基于现有 `http` 包封装一个极简 JSON-RPC 客户端，仅支持 `eth_getBalance` 和 `eth_call`。

9. **错误处理**
   - RPC 失败：首页给出可重试提示，不阻塞其他资产展示。
   - 合约不可读：添加代币时实时提示，拒绝保存非标准合约。

## 考虑的选项

- **Alchemy / Infura Token API**：可自动发现代币且元数据完整，但需要 API key、引入外部依赖、存在隐私和速率问题。拒绝原因：与冷钱包"最小外部信任"原则冲突，且用户希望免费可用。
- **区块浏览器 API（Etherscan 等）**：同样能提供代币余额，但各链 API 不统一、需要 key、有调用限制。拒绝原因：配置复杂，不如公共 RPC 简洁。
- **自动扫描地址历史代币**：体验好，但实现重、依赖索引服务或大量 RPC 调用。拒绝原因：先满足基础手动添加，后续再迭代自动发现。
- **复用 `AssetBalance` 模型**：可减少模型数量，但 `unit` 字段在 Cardano 与 EVM 下语义差异大，容易混淆。拒绝原因：先独立模型保持清晰，稳定后再考虑泛化。

## 影响

- 新增 `EvmRpcService`：基于 `http` 的极简 JSON-RPC 客户端。
- 新增 `EvmAssetService`：按链查询原生余额与 ERC-20 余额，组装 `List<EvmAssetBalance>`。
- 新增 `EvmAssetBalance` 模型。
- 新增 `EvmTokenManager` 或等价逻辑：管理每链全局的 ERC-20 合约地址列表，持久化到 `StorageService`。
- 修改 `HomeScreen._loadBalances()`：EVM 钱包路由到 `EvmAssetService`。
- 修改 `SettingsScreen`：新增 EVM RPC 覆盖输入框和 "管理 EVM 代币" 入口。
- 新增 "管理 EVM 代币" 页面：添加/删除代币合约，实时校验 ERC-20 可读性。
- 更新 `CONTEXT.md` 术语表：补充原生代币、ERC-20 代币、合约地址等定义。
- 新增单元/小部件测试覆盖 RPC 调用、余额解析、代币添加校验和首页展示。
