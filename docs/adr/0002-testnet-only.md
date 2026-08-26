# 网络固定：所有链锁定测试网

**Status**: superseded by [ADR-0003](0003-network-switch.md)

各链固定为对应测试网（Cardano: preview, EVM: Sepolia/BSC Testnet/Arbitrum Sepolia/Polygon Amoy/Base Sepolia），不提供网络切换 UI 或主网选项。

这个决策的动机是：项目处于开发验证阶段，固定测试网可以避免主网资产误操作风险，同时大幅简化代码（无需处理网络切换逻辑、多网络状态管理和主网安全检查）。代价是正式上线时需要全面放开网络配置，但由于 ChainConfig 已经抽象了网络标识，改动集中在 ChainRegistry 的静态配置表中。
