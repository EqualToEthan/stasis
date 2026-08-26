# DRep 弃权委托并入质押委托流程

## Status

resolved

## 背景

Cardano Conway 时代要求 stake key 在提取奖励的交易**之前**就已委托给 DRep（或 abstain / no-confidence）。ledger 的 `validateWithdrawalsDelegated` 检查在 CERTS 规则之前、用证书应用前的账户状态快照执行——因此**弃权证书与奖励提取不可能同笔交易**（这正是 `ConwayWdrlNotDelegatedToDRep` 报错的成因，链上规则无法绕过）。

当前实现（`buildVoteDelegation` 独立弃权交易 + `buildWithdrawReward` 纯 withdrawal）是对该规则的正确拆分，但要求冷钱包签名三次（委托 pool → 弃权 → 提奖励）。

## 目标

把弃权证书搭载进「委托给 Pool」的交易，全流程签名次数从 3 次降到 2 次（链上规则下限）；弃权对用户无感化。

## 已决策（grilling 2026-08-26）

原 Q1-Q5 全部落定：

### Q1: DRep 委托的入口位置 → 合并进 buildDelegate()

弃权证书（`Certificate.voteDelegation` + `Drep.abstain`）与 stakeDelegation 证书同笔构建，随委托交易一次签名。`buildWithdrawReward` 保持纯 withdrawal，不含任何证书。`buildVoteDelegation` 独立方法及其 UI 入口删除。

### Q2: DRep 选择 UI 的暴露程度 → 无选择 UI，保留只读状态展示

不提供 DRep 选择（项目定死 abstain-only，见 Q3）。StakingScreen 质押信息卡保留一行只读的 DRep 委托状态（如「DRep 委托：弃权（自动）」），作为奖励提取前置条件的可见性线索。

### Q3: 后续更换 DRep 的入口 → 不提供，治理功能后续再规划

产品范围定死 abstain-only：委托具体 DRep / no-confidence 不在当前范围。协议层 `dRepType` 字段枚举已预留扩展点，将来支持时只需加 UI 入口。

### Q4: 证书形态 → 独立 Certificate.voteDelegation

委托交易内两个独立证书：stakeDelegation（pool）+ voteDelegation（abstain）。不用组合证书 stakeVoteDelegation。

### Q5: 协议层证书类型 → 新增 voteDelegation 类型

coldwallet-protocol 的 `Certificate` 新增 `voteDelegation` 证书类型与 `dRepType` 字段（+ 可选 `dRepHash`），替代当前借用 `stakeDelegation` + `poolKeyHash: 'drep-abstain'` 魔法字符串的占位方案。

### 补充决策

- **独立弃权按钮删除**：StakingScreen 的「委托 DRep（弃权）」按钮移除。
- **无存量兜底**：已委托 pool 但未弃权的存量账户不存在（当前无存量用户），不做检测提示逻辑，报错原文即兜底。此假设仅对测试网成立，主网正式上线后需重新评估。

## 影响范围

- `coldwallet-protocol/lib/cardano/certificate.dart` — 新增 `voteDelegation` 证书类型、`dRepType` / `dRepHash` 字段
- `coldwallet-watch/lib/services/stake_transaction_builder.dart` — `buildDelegate` 生成双证书；`buildVoteDelegation` 删除；`buildWithdrawReward` 保持纯 withdrawal
- `coldwallet-watch/lib/screens/staking_screen.dart` — 删除「委托 DRep（弃权）」按钮与 `_buildDRepDelegation`；保留只读 DRep 状态展示
- `coldwallet-app/lib/services/adapters/cardano_adapter.dart` — 签名逻辑识别 voteDelegation 证书
- `coldwallet-app/lib/screens/tx_detail_screen.dart` — 展示 voteDelegation 信息
- `PROTOCOL.md` — Certificate 类型清单补充 voteDelegation
- 相关测试（stake_transaction_builder_test、staking_screen_test、tx_detail_screen_test）与各模块 README

## 关联文档

- ADR：`docs/adr/0004-drep-abstain-rides-delegate-tx.md`
- 词汇表：`CONTEXT.md` 的「DRep 委托」「弃权」词条

## 记录时间

2026-08-25（提出）· 2026-08-26（grilling 决策）

## 备注

原始备注曾声称「当前修复（仅 buildWithdrawReward 自动 abstain）已经能让奖励提取通过链上校验」——**该说法有误**：ledger 对 withdrawal 的 DRep 检查用交易前的账户状态快照，同笔交易内附带的弃权证书对检查不可见，链上必然报 `ConwayWdrlNotDelegatedToDRep`。当时的「通过」大概率只验证到单元测试层（断言证书存在）。当前代码（拆分方案）才是正确实现。

## Comments

**2026-08-26 实施完成**（agent）：全部已决策项落地——协议层 voteDelegation 证书类型与 dRepType/dRepHash 字段、buildDelegate 三证书（注册? + pool 委托 + abstain）、buildVoteDelegation 删除、StakingScreen 弃权按钮移除与 drepStatus 只读展示、tx_detail_screen DRep 委托卡片、PROTOCOL.md 与各模块 README 同步。验证：coldwallet-protocol 15/15、coldwallet-watch 47/47、coldwallet-app 50/50 测试通过，三包 analyze 无问题，两端 Debug APK 构建成功。实施中修复一处测试断言类型名（`Certificate_StakeRegistration` → `Certificate_StakeRegistrationLegacy`，SDK 中 legacy 注册证书与 Conway 版注册证书是不同类）。
