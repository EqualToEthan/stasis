# 0008. EVM 数据查询统一公共 RPC，拒绝 Etherscan API

日期：2026-08-28
状态：已接受

## 背景

EVM 链余额查询此前依赖各链公共 JSON-RPC 端点。实测发现 BSC 默认端点 `bsc-dataseed.binance.org` 在用户网络环境下**间歇性挂死**（TCP 连接建立后无响应，10 秒零字节超时），且存在两个放大问题的代码缺陷：

1. `EvmRpcService._call` 无超时——挂死端点导致余额加载永久卡住
2. HomeScreen 单链查询失败被 `catch (_) {}` 静默吞掉——"查询失败"与"余额为 0"在 UI 上不可区分

用户持有 Etherscan API key（免费层），提出用 Etherscan V2 多链 API 统一数据查询。Etherscan V2 确实支持一个 key 通过 `chainid` 参数查询 60+ 链。

## 决策

**所有 EVM 链数据查询统一走公共 JSON-RPC 端点，不引入 Etherscan API。**

具体措施：

1. **端点统一换用经验证的服务商**：BSC 主网/测试网端点换为 PublicNode（`bsc.publicnode.com` / `bsc-testnet.publicnode.com`）；恢复 Ethereum 主网与 Sepolia 配置（端点 `ethereum-rpc.publicnode.com` / `ethereum-sepolia-rpc.publicnode.com`）；Arbitrum/Base 保持官方端点。
2. **RPC 调用统一 15 秒超时**：`EvmRpcService._call` 内部实施，杜绝挂死连锁。
3. **单链查询失败显示行内错误态**：按链独立记录失败状态，余额区显示"该链查询失败"+ 重试按钮，与"加载中""余额为 0"三态可区分。
4. **单端点策略**：每链一个默认端点，失败靠重试按钮 + 设置页自定义 RPC 逃生，不做多端点自动回退。

## 理由

拒绝 Etherscan 的三个理由：

1. **免费层链覆盖不足**：用户支持的 4 条 EVM 链中，Etherscan 免费层仅覆盖 Arbitrum；BSC（56/97）与 Base（8453/84532）均为付费层（LITE 套餐 $49/月起）。引入后同一功能将出现"Arbitrum 走 Etherscan、其余走 RPC"的双数据路径，复杂度收益比极差。
2. **客户端 key 暴露**：coldwallet-watch 是纯客户端应用无后端，Etherscan 官方文档明确建议"不要把 key 放进客户端代码，应经自有后端转发"。Key 进入浏览器 localStorage 与该安全建议冲突（Blockfrost key 已有同样问题，无必要再增加一个）。
3. **无独有价值场景**：EVM 数据需求当前仅有余额查询与 ERC-20 元数据读取，公共 RPC 完全胜任且免费。Etherscan 的独有能力（交易历史、日志检索）当前无需求。

选择 PublicNode 的理由：免费、无 key、CORS 全开放、经浏览器实测从用户网络稳定可达（dataseed 同场景 6 次测试 4 次挂死）；一家服务商覆盖 ETH/BSC 全部主网+测试网端点，管理成本低。

## 后果

- Etherscan key 保留在用户手中不进入应用。未来若做**交易历史查询**（RPC 无法实现的能力），届时再评估引入 Etherscan——那是它有真实不可替代价值的场景。
- 新增链时优先寻找免费公共 RPC 端点；找不到再议付费方案。
- "一个端点查所有链"在 RPC 世界不存在：每链一个端点是技术必然。Etherscan 的"一个 key 查所有链"特性（仅付费层覆盖全链）不构成引入理由。
- 相关术语（RPC 端点 vs API Key）已录入 CONTEXT.md 词汇表。
