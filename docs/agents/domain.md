# 领域文档

工程 skill 在探索代码库时，如何消费本仓库的领域文档。

## 探索前先阅读

- **`CONTEXT.md`**：位于仓库根目录，或
- **`CONTEXT-MAP.md`**：若存在于仓库根目录，它指向每个上下文的 `CONTEXT.md`，阅读与当前主题相关的部分
- **`docs/adr/`**：阅读与你即将工作区域相关的 ADR。多上下文仓库还需检查 `src/<context>/docs/adr/` 中的上下文级决策

如果这些文件不存在，**静默继续**。不要标记缺失，不要建议创建。`/domain-modeling` skill（通过 `/grill-with-docs` 和 `/improve-codebase-architecture` 触达）会在术语或决策实际需要时才懒加载创建它们。

## 文件结构

单上下文仓库（大多数仓库）：

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

多上下文仓库（根目录存在 `CONTEXT-MAP.md`）：

```
/
├── CONTEXT-MAP.md
├── docs/adr/                          ← 系统级决策
└── src/
    ├── ordering/
    │   ├── CONTEXT.md
    │   └── docs/adr/                  ← 上下文级决策
    └── billing/
        ├── CONTEXT.md
        └── docs/adr/
```

## 使用术语表的词汇

当你的输出涉及领域概念时（issue 标题、重构提案、假设、测试名称），使用 `CONTEXT.md` 中定义的术语。不要偏移到术语表明确避免的同义词。

如果你需要的概念不在术语表中，这是一个信号：要么你在使用项目未采用的语言（重新考虑），要么存在真实缺口（记录下来供 `/domain-modeling` 处理）。

## 标记 ADR 冲突

如果你的输出与现有 ADR 矛盾，显式标记而非静默覆盖：

> _与 ADR-0007（事件溯源订单）矛盾，但值得重新讨论，因为…_
