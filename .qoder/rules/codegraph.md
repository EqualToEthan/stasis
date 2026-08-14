---
description: 全工作区强制使用 codegraph MCP 做代码结构分析
trigger: always_on
---

<!-- CODEGRAPH_START -->
## CodeGraph 强制使用规则（项目级）

本项目已配置 codegraph MCP。CodeGraph 是基于 tree-sitter 的完整 AST 索引，提供符号、调用边、文件层级的结构化查询。

### 可用工具（codegraph v1.5.0）

MCP 服务器**只暴露一个工具**：`codegraph_explore`

| 参数 | 说明 |
|---|---|
| `projectPath` | 项目绝对路径，codegraph 自动找到最近的 `.codegraph/` 索引 |
| `query` | 符号名、文件名、或自然语言问题 |
| `maxFiles` | 最大返回文件数（默认 12） |

返回的源码等同于 Read 结果，不需要再次 Read。

> **CLI 命令参考**（`codegraph <cmd>`，不通过 MCP 调用）：
> explore、node、query、callers、callees、impact、files、status、sync、affected

### 强制条款（必须遵守）

1. **凡涉及"代码结构分析"的任务，第一步必须调用 `codegraph_explore`，禁止直接用 Grep/Read 探索代码结构。**
2. **触发关键词**（用户消息中出现下列任一，即视为结构分析任务）：
   - 分析 / 看一下 / 梳理 / 追溯 / 定位
   - 调用链 / 调用关系 / 谁调用 / 影响面 / 依赖
   - 找定义 / 在哪里定义 / 这个方法是做什么的
   - 重构 / 修改 / 改动某个方法或类（未指定具体文件时）
3. **未使用 codegraph 直接给出结构性结论的回答视为违规**，用户可要求重新回答。

### 查询技巧

通过 `codegraph_explore` 的 `query` 参数使用不同写法：

| 用户问题类型 | `query` 写法 |
|---|---|
| X 在哪里定义 / 找符号 X | `"X"` 或 `"X definition"` |
| 谁调用了 Y | `"Y callers"` 或 `"who calls Y"` |
| Y 调用了什么 | `"Y callees"` 或 `"what does Y call"` |
| X 到 Y 的完整调用路径 | `"X to Y call path"` |
| 改动 Z 会影响哪些地方 | `"Z impact"` 或 `"Z usage"` |
| 看 Y 的签名/源码 + 调用链 | `"Y"` 直接查 |
| 一次拿多个相关符号的源码 | `"ClassA ClassB methodC"` 传多个符号 |
| 某个功能/模块的整体上下文 | 用自然语言，如 `"wallet creation flow"` |

### 使用要领

- **一次调用给答案，不做冗余验证。** 结构问题优先用 `codegraph_explore` 一次拿到全貌，不要再用 grep 交叉验证结果。
- **多个相关符号放在一个 query 里**，不要多次单独调用。
- **索引过期提示：** 若响应开头出现 "⚠️ Some files ... edited since the last index sync"，对提示中列出的文件用 Read 补读，未列出的文件以 codegraph 为准。
- **索引缺失：** 若 codegraph 返回 "not initialized"，提示用户运行 `codegraph init` 建立索引。

### 允许直接用 Grep/Read 的例外场景

以下场景不受强制条款约束：

- 查字符串字面量、日志消息、注释文本、配置项内容
- 用户已明确指定某个具体文件路径，只做该文件内的读写
- 目标子项目 `.codegraph/` 目录缺失
- 非代码文件（Markdown、Excel、SQL 脚本、配置文件）内容检索

### 违规自查清单

回答代码结构问题前，AI 自检：

- [ ] 本次回答涉及的是代码结构（调用/定义/影响面）还是文本内容？
- [ ] 若是结构 —— 我是否已经调用了 `codegraph_explore`？
- [ ] 我是否用 grep 结果替代了本该由 codegraph 给出的结构结论？

任一项不满足 → 立即补调 `codegraph_explore` 后重答。
<!-- CODEGRAPH_END -->
