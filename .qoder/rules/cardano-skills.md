---
description: Cardano 开发任务强制使用对应技能（Skill）文档
trigger: always_on
---

<!-- CARDANO_SKILLS_START -->
## Cardano 技能强制使用规则（项目级）

本项目已通过符号链接挂载 Cardano 开发技能集（`.agents/skills` → `D:\code\cardano-dev-skills\skills`）。技能文档是社区最佳实践的提炼，比 AI 训练数据更准确、更及时。

### 强制条款（必须遵守）

1. **凡涉及 Cardano 开发的任务，必须先查阅对应技能文档，再给出代码或建议。** 禁止仅凭训练数据记忆回答 Cardano 专业问题。
2. **触发关键词**（用户消息中出现下列任一，即视为 Cardano 开发任务）：
   - 交易构建 / 转账 / 铸造 / 委托 / 质押 / DRep / 治理投票
   - CIP-1852 / CIP-30 / CIP-1694 / CIP-25 / CIP-68 等任何 CIP 编号
   - eUTxO / datum / redeemer / validator / 验证器
   - Aiken / Plutus / OpShin
   - Blockfrost / Ogmios / Mesh SDK / PyCardano / cardano-client-lib
   - stake key / reward address / 链上查询
3. **未查阅对应技能文档直接给出 Cardano 专业结论的回答视为违规**，用户可要求重新回答。

### 技能与任务匹配表

| 任务场景 | 必须查阅的技能 | 斜杠命令 |
|----------|--------------|----------|
| 构建交易（转账 ADA、委托、铸造、DRep 投票） | `build-transaction` | `/build-transaction` |
| 调试失败交易（报错排查） | `debug-transaction` | `/debug-transaction` |
| 理解 CIP 标准（CIP-1852 地址派生等） | `explain-cip` | `/explain-cip` |
| 理解 eUTxO 模型（datum、redeemer、验证器） | `explain-eutxo` | `/explain-eutxo` |
| Conway 时代链上治理、DRep 委托 | `governance-guide` | `/governance-guide` |
| 查询链上数据（余额、UTxO、质押状态） | `query-chain` | `/query-chain` |
| 编写智能合约验证器（Aiken） | `write-validator` | `/write-validator` |
| 优化验证器（降低执行成本） | `optimize-validator` | `/optimize-validator` |
| 合约安全审计 | `review-contract` | `/review-contract` |
| 设计原生代币 / NFT / 元数据 | `design-token` | `/design-token` |
| CIP-30 钱包集成（Web dApp） | `connect-wallet` | `/connect-wallet` |
| 选择 SDK 和工具链 | `suggest-tooling` | `/suggest-tooling` |
| 搭建本地开发环境（Yaci DevKit） | `setup-devnet` | `/setup-devnet` |
| 从零创建 Cardano 项目脚手架 | `scaffold-project` | `/scaffold-project` |

### 查阅方式

- **技能文档位置**：`.agents/skills/<技能名>/SKILL.md`
- **查阅方法**：用 Read 工具读取对应 SKILL.md 文件，提取关键步骤和注意事项后再回答
- **一次查阅多个技能**：若任务跨多个领域，可一次读取多个 SKILL.md

### 允许不查阅技能的例外场景

以下场景不受强制条款约束：

- 用户明确说"不用查技能，直接回答"
- 非 Cardano 相关任务（如 Flutter UI、Dart 语法、通用逻辑）
- 用户已提供完整的代码或规格，仅需按其指示执行
- 查找项目中已有的代码文件（用 codegraph 或 Grep）

### 违规自查清单

回答 Cardano 相关问题前，AI 自检：

- [ ] 本次回答是否涉及 Cardano 区块链开发？
- [ ] 若涉及 —— 我是否已经读取了对应技能的 SKILL.md 文档？
- [ ] 我是否仅凭训练数据记忆给出了 Cardano 专业结论？

任一项不满足 → 立即补读对应技能文档后重答。
<!-- CARDANO_SKILLS_END -->
