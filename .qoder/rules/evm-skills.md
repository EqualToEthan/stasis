---
description: EVM 开发任务强制使用 ETHSkills 技能文档
trigger: always_on
---

<!-- EVM_SKILLS_START -->
## ETHSkills 强制使用规则（项目级）

本项目已挂载 ETHSkills（ethskills.com）—— 官方推荐的 Ethereum/EVM 知识库。技能文档比 AI 训练数据更准确、更及时（Gas 价格、ERC 标准、L2 现状等均已过时）。

### 技能来源

- **本地路径**：`.agents/evm-skills/<skill>/SKILL.md`
- **索引文件**：`.agents/evm-skills/SKILL.md`（主入口，含技能路由表）
- **查阅方法**：用 Read 工具读取对应 SKILL.md 文件，提取关键知识后再回答
- **在线备份**：若本地文件缺失，可用 WebFetch 从 `https://ethskills.com/<skill>/SKILL.md` 在线获取
- **技能总数**：22 个技能 + 1 个索引（共 23 个文件，293 KB）

### 强制条款（必须遵守）

1. **凡涉及 EVM/Ethereum 开发的任务，必须先 Read 对应技能文档，再给出代码或建议。** 禁止仅凭训练数据记忆回答 EVM 专业问题。
2. **触发关键词**（用户消息中出现下列任一，即视为 EVM 开发任务）：
   - Ethereum / EVM / Solidity / Foundry / Hardhat
   - ERC-20 / ERC-721 / ERC-1155 / ERC-4626 等任何 ERC 编号
   - EIP-155 / EIP-1559 / EIP-712 / EIP-7702 等任何 EIP 编号
   - Gas / gaslimit / gasprice / base fee
   - Sepolia / BSC Testnet / Arbitrum Sepolia / Polygon Amoy / Base Sepolia
   - MetaMask / EIP-712 签名 / typed data 签名
   - 代币精度 / decimals / SafeERC20
   - 闪电贷 / MEV / 三明治攻击 / 重入
   - RPC / Infura / Alchemy / block explorer
3. **未查阅对应技能文档直接给出 EVM 专业结论的回答视为违规**，用户可要求重新回答。

### 技能与任务匹配表

| 任务场景 | 必须查阅的技能 | 本地路径 |
|----------|--------------|----------|
| 钱包创建、密钥安全、签名、多签、账户抽象 | `wallets` | `.agents/evm-skills/wallets/SKILL.md` |
| ERC 标准（ERC-20/721/1155/4626）、EIP-7702 | `standards` | `.agents/evm-skills/standards/SKILL.md` |
| Gas 计算、交易成本、mainnet vs L2 成本 | `gas` | `.agents/evm-skills/gas/SKILL.md` |
| L2 选型、Arbitrum/Optimism/Base/zkSync/Polygon | `l2s` | `.agents/evm-skills/l2s/SKILL.md` |
| EIP 生命周期、协议演进、分叉跟踪 | `protocol` | `.agents/evm-skills/protocol/SKILL.md` |
| Solidity 安全模式、常见漏洞、预部署检查 | `security` | `.agents/evm-skills/security/SKILL.md` |
| 工具链选型（Foundry、Hardhat、RPC、区块浏览器） | `tools` | `.agents/evm-skills/tools/SKILL.md` |
| 核心概念（函数调用者、激励设计、随机性陷阱） | `concepts` | `.agents/evm-skills/concepts/SKILL.md` |
| 合约地址查询（Uniswap、Aave 等已验证地址） | `addresses` | `.agents/evm-skills/addresses/SKILL.md` |
| 从零构建 dApp（端到端路由） | `ship` | `.agents/evm-skills/ship/SKILL.md` |
| CROPS 架构审查 | `crops` | `.agents/evm-skills/crops/SKILL.md` |
| Foundry 测试（fuzz、invariant） | `testing` | `.agents/evm-skills/testing/SKILL.md` |
| 合约审计（500+ 检查项、19 个领域） | `audit` | `.agents/evm-skills/audit/SKILL.md` |
| 链上数据索引（events、The Graph、Dune） | `indexing` | `.agents/evm-skills/indexing/SKILL.md` |

### 冷钱包项目常用技能

本项目是 Flutter 冷钱包，EVM 侧主要做交易构建和离线签名，以下技能最常用：

| 优先级 | 技能 | 原因 |
|--------|------|------|
| 高 | `wallets` | 钱包创建、签名、密钥安全是冷钱包核心 |
| 高 | `standards` | ERC-20/721 代币交互需要正确的接口和精度 |
| 高 | `gas` | 交易构建需要正确的 Gas 估算 |
| 高 | `l2s` | 项目支持 Arbitrum/Base/Polygon/BSC 多链 |
| 中 | `protocol` | 理解 EIP 标准的演进和当前状态 |
| 中 | `security` | 离线签名的安全模式、常见漏洞防范 |
| 中 | `concepts` | 理解 EVM 的核心心智模型 |
| 低 | `tools` | 工具链选型参考 |
| 低 | `addresses` | 已验证的合约地址查询 |

### 按任务类型的查阅指南

| 我在做... | 需 Read 的技能 |
|-----------|----------------|
| 构建 EVM 未签名交易 | `wallets`, `standards`, `gas` |
| 实现 ERC-20 代币转账 | `standards`, `security` |
| 实现 EIP-712 typed data 签名 | `wallets`, `standards` |
| 选择 L2 链配置 | `l2s`, `gas` |
| 理解 EIP-1559 费用机制 | `protocol`, `gas` |
| 估算交易 Gas 成本 | `gas` |
| 安全审查 EVM 相关代码 | `security`, `concepts` |

### 允许不查阅技能的例外场景

以下场景不受强制条款约束：

- 用户明确说"不用查技能，直接回答"
- 非 EVM 相关任务（如 Flutter UI、Dart 语法、通用逻辑）
- Cardano 相关任务（使用 Cardano 技能规则）
- 用户已提供完整的代码或规格，仅需按其指示执行
- 查找项目中已有的代码文件（用 codegraph 或 Grep）

### 违规自查清单

回答 EVM/Ethereum 相关问题前，AI 自检：

- [ ] 本次回答是否涉及 EVM/Ethereum 开发？
- [ ] 若涉及 —— 我是否已经 Read 了对应技能的本地 SKILL.md 文档？
- [ ] 我是否仅凭训练数据记忆给出了 EVM 专业结论？

任一项不满足 → 立即补 Read 对应技能文档后重答。

**本地文件缺失时的降级策略**：若 `.agents/evm-skills/<skill>/SKILL.md` 不存在，降级使用 WebFetch 从 `https://ethskills.com/<skill>/SKILL.md` 在线获取。
<!-- EVM_SKILLS_END -->
