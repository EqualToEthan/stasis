# Issue tracker: 本地 Markdown

本仓库的 Issue 和规格文档以 Markdown 文件形式存储在 `.scratch/` 目录下。

## 约定

- 每个功能一个目录：`.scratch/<feature-slug>/`
- 规格文档：`.scratch/<feature-slug>/spec.md`
- 实现工单：每个 ticket 一个文件，位于 `.scratch/<feature-slug>/issues/<NN>-<slug>.md`，从 `01` 开始编号，不合并为单文件
- Triage 状态记录在每个 issue 文件顶部的 `Status:` 行（角色字符串参见 `triage-labels.md`）
- 评论和对话历史追加到文件底部的 `## Comments` 标题下

## 当 skill 说"发布到 issue tracker"时

在 `.scratch/<feature-slug>/` 下创建新文件（目录不存在则创建）。

## 当 skill 说"获取相关 ticket"时

读取引用路径处的文件。用户通常会直接传入路径或 issue 编号。

## Wayfinding 操作

由 `/wayfinder` 使用。**地图**是一个文件，每个**子工单**对应一个子文件。

- **地图**：`.scratch/<effort>/map.md`（笔记 / 已做决策 / 迷雾主体）
- **子工单**：`.scratch/<effort>/issues/NN-<slug>.md`，从 `01` 开始编号，问题写在正文中。`Type:` 行记录工单类型（`research`/`prototype`/`grilling`/`task`）；`Status:` 行记录 `claimed`/`resolved`
- **阻塞**：顶部附近的 `Blocked by: NN, NN` 行。当所有列出的文件状态为 `resolved` 时，工单解除阻塞
- **前沿**：扫描 `.scratch/<effort>/issues/` 中处于开放、未阻塞、未认领状态的文件，编号最小的优先
- **认领**：开始任何工作前，设置 `Status: claimed` 并保存
- **解决**：在 `## Answer` 标题下追加答案，设置 `Status: resolved`，然后将上下文指针（摘要 + 链接）追加到 `map.md` 的"已做决策"部分
