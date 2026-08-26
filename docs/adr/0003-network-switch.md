# 网络可切换：全局开关 + 双组配置

各链网络由 coldwallet-protocol 中 `AppConfig.isMainnet` 全局开关控制。ChainRegistry 维护测试网和主网两组 ChainConfig，运行时按开关值激活一组。切换主网只需改 `isMainnet = true`，两个 app 同步生效。冷钱包签名前校验 ColdExport.network 与开关一致，防止两端 app 版本不同步导致的网络不匹配。此决策替代 ADR-0002（测试网固定）。

## Considered Options

- **全局开关 + 两组配置（采纳）**：ChainRegistry 有 `_testnetConfigs` 和 `_mainnetConfigs`，`AppConfig.isMainnet` 选组。改一个字段切主网。
- **暴力改所有硬编码值**：把散落在 12+ 处的 `testnet = true`、`'preview'`、`'sepolia'` 等逐个改成主网值。被否决：每次测试网/主网来回都要改十几处，容易遗漏。
- **dart-define 编译时注入**：用 `--dart-define=IS_MAINNET=true` 控制。被否决：Dart 中 const 读法绕，且两组配置需要条件编译不如 C/C++ 优雅。
- **每条 ChainConfig 存双份参数**：ChainConfig 加 mainnetEvmChainId、mainnetNetwork 等字段。被否决：让单条链模型承担两个网络的参数，职责膨胀，且 Cardano 不需要双份。
- **运行时网络切换 UI**：用户在 app 里选测试网/主网。被否决：冷钱包场景下引入误操作风险，且 ADR-0002 已确立"不提供网络切换 UI"原则，本决策继承此原则——切换是编译时行为，不是运行时行为。

## Consequences

- **coldwallet-protocol 职责扩展**：从纯协议模型包变成"协议模型 + 链配置 + 全局开关"包。两个项目都依赖它，改一处两端同步。
- **ChainRegistry 拆分**：配置数据（`_configs`、`getConfig`、`allConfigs`）移到 coldwallet-protocol；适配器查找（`adapterFor`）留在 coldwallet-app 的 AdapterRegistry，因为适配器含私钥派生逻辑。
- **WalletService 签名简化**：`createWallet`、`deriveAddress`、`deriveStakeAddress` 不再接受 `testnet` 参数，内部读 `AppConfig.isMainnet`。
- **SecureStorageService 瘦身**：删除 `current_network` 存储 key 和 `getNetwork`/`setNetwork`/`isTestnet` 方法。网络不再是运行时存储状态。
- **ColdExport.network 保留但角色变化**：从"告诉冷钱包用什么网络"变成"跨设备网络一致性校验"。冷钱包收到 ColdExport 后校验其 network 与自身 `AppConfig.isMainnet` 一致，不一致拒绝签名。
- **非 const 开关**：`AppConfig.isMainnet` 是 `static bool` 而非 `static const`，允许测试注入。代价是理论上运行时可变，但该值不暴露给 UI、不读写存储，风险可忽略。
