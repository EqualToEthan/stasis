# 文档格式规范

源码文件变更后，按以下规范更新对应文档。

## 一、代码注释（方法级）

被修改的 Dart 文件中，确保：

- **文件头部**：用一句话概述该文件的职责
- **类注释**：说明类的职责和使用场景
- **公开方法**：用 `///` 文档注释描述做了什么、为什么、关键参数和返回值

```dart
/// 钱包服务，负责助记词管理和多链地址派生。
class WalletService {
  /// 根据助记词和链配置派生指定索引的地址。
  ///
  /// [mnemonic] BIP-39 助记词
  /// [chain] 链配置，决定派生路径格式
  /// [index] 地址索引
  /// 返回派生后的地址字符串
  Future<String> deriveAddress(String mnemonic, ChainConfig chain, int index) async {
    ...
  }
}
```

## 二、模块 README（功能级）

每个 `lib/` 下的源码目录维护一份 `README.md`，与代码文件同级。

### README 结构

```markdown
# 模块名称

一句话描述本目录的职责。

## 实现逻辑

核心业务流程和设计决策（2-3 段）。

## 调用关系

与其他模块的调用依赖（文字或 mermaid 图）：
- 被谁调用
- 调用谁
- 模块内部调用链

## 文件清单

| 文件/目录 | 主要类/函数 | 功能说明 |
|----------|------------|----------|
| wallet.dart | WalletService | 钱包地址派生和管理 |
| [adapters/](adapters/README.md) | - | 链适配器层 |

## 依赖关系

- **内部依赖**：models/、services/chain_registry.dart
- **外部依赖**：cardano_flutter_sdk、web3dart

## 常见修改指引

| 我想... | 修改文件 |
|---------|---------|
| 添加新链族 | adapters/ 下新建适配器 + chain_registry.dart |
| 修改地址派生逻辑 | wallet_service.dart |
```

### 维护规则

| 操作 | README 更新 |
|------|------------|
| 新增文件 | 添加文件清单条目，必要时更新实现逻辑和调用关系 |
| 删除文件 | 移除条目，清理调用关系 |
| 重命名/移动文件 | 更新文件名和调用关系引用 |
| 修改调用逻辑 | 更新调用关系部分 |
| 新增子目录 | 创建子目录 README + 在当前目录添加条目 |

## 三、PROTOCOL.md

修改 `ColdExport`、`ColdImport`、`EthColdExport`、`EthColdImport` 等通信模型时，同步更新项目根目录的 `PROTOCOL.md`。
