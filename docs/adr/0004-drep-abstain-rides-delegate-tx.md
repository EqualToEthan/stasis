# DRep 弃权委托搭载质押委托交易

Cardano Conway 时代要求 stake key 在提取奖励的交易**之前**就已委托 DRep——ledger 的 `validateWithdrawalsDelegated` 检查在 CERTS 规则之前、用证书应用前的账户状态快照执行，因此弃权证书与 withdrawal 永远不能同笔交易（这正是 `ConwayWdrlNotDelegatedToDRep` 报错的成因，链上规则无法绕过）。同时本项目定死 abstain-only：不支持委托具体 DRep，治理功能后续再规划。为把冷钱包签名次数降到链上规则允许的下限，弃权证书（`voteDelegation` + `abstain`）合并进质押委托交易一并签署，StakingScreen 的独立弃权按钮删除，仅保留只读的 DRep 状态展示。

## Considered Options

- **弃权证书与 withdrawal 同笔**：被链上规则排除——本交易的证书对自身的 withdrawal 检查不可见，必然报 `ConwayWdrlNotDelegatedToDRep`。
- **领取奖励时自动前置弃权流程**（引导用户连签两笔）：签名次数仍为 2 次，且需跨交易等待链上确认后才能构建第二笔，实现复杂度最高、收益最低。
- **维持三笔独立流程**（委托 / 弃权 / 提奖励）：签名 3 次，多出的一次无收益。

## Consequences

- 全流程（委托 → 提奖励）的 2 次冷钱包签名是 Conway 规则下的下限。
- 协议层（coldwallet-protocol）新增 `voteDelegation` 证书类型与 `dRepType` 字段，替代此前借用 `stakeDelegation` + `poolKeyHash: 'drep-abstain'` 魔法字符串的占位方案。
- 已委托 pool 但未弃权的存量账户没有独立补弃权入口——决策依据是当前无存量用户；此假设仅对测试网成立，主网正式上线后若再遇此场景需重新决策。
- `dRepType` 枚举（abstain | noConfidence | keyHash | scriptHash）为将来的治理功能预留了协议扩展点，届时只需加 UI 入口，无需动协议。
