# 多链冷钱包项目

## 项目概述

多链冷钱包系统，支持 Cardano、EVM（Ethereum/BSC/Arbitrum/Polygon/Base）等链族，包含两个 Flutter 应用：

| 子项目 | 说明 | 文档入口 |
|--------|------|----------|
| **coldwallet-app** | 离线冷钱包 — 助记词管理、多链地址派生、扫码签名、交易文件导入导出 | [coldwallet-app/lib/README.md](coldwallet-app/lib/README.md) |
| **coldwallet-watch** | 联网观察钱包 — 查看余额、构建未签名交易、扫码/文件导入导出已签名交易 | [coldwallet-watch/lib/README.md](coldwallet-watch/lib/README.md) |

两端通过 JSON 格式交换数据（Cardano: `ColdExport`/`ColdImport`，EVM: `EthColdExport`/`EthColdImport`），传输方式支持二维码和文件导出/导入。详见 [PROTOCOL.md](PROTOCOL.md)。

## 网络配置

各链固定为对应测试网，不允许网络切换 UI 或逻辑：
- Cardano: preview testnet
- EVM: Sepolia / BSC Testnet / Arbitrum Sepolia / Polygon Amoy / Base Sepolia

## 项目结构

```
coldwallet/
├── coldwallet-app/          # 离线冷钱包 Flutter 应用（多链）
│   ├── lib/
│   │   ├── models/          # 数据模型（chain_config, cold_export, eth_cold_export 等）
│   │   ├── screens/         # UI 页面（home, wallet_setup, confirm_sign 等）
│   │   ├── services/        # 业务服务（wallet, transaction, chain_registry）
│   │   │   └── adapters/    # 链适配器（chain_adapter, cardano_adapter, evm_adapter）
│   │   └── README.md        # 模块文档索引
│   └── test/
├── coldwallet-watch/        # 联网观察钱包 Flutter 应用
│   ├── lib/
│   │   ├── models/          # 数据模型（watch_wallet, asset_balance 等）
│   │   ├── screens/         # UI 页面（home, add_wallet, send, receive 等）
│   │   ├── services/        # 业务服务（blockfrost, wallet, asset）
│   │   ├── widgets/         # 可复用组件
│   │   └── README.md        # 模块文档索引
│   └── test/
├── docs/superpowers/        # 设计文档和开发计划
└── PROTOCOL.md              # 冷热钱包通信协议定义
```

## 验证命令

涉及 UI 改动或重要逻辑变更时，手动运行以下验证：

```bash
# 运行测试
cd coldwallet-app && flutter test
cd coldwallet-watch && flutter test

# 构建检查（Debug APK）
cd coldwallet-app && flutter build apk --debug
cd coldwallet-watch && flutter build apk --debug
```

## 依赖管理

```bash
# 获取依赖
cd coldwallet-app && flutter pub get
cd coldwallet-watch && flutter pub get
```

Flutter SDK: ^3.11.1，Dart SDK: ^3.11.1。

## 关键约定

- HomeScreen 仅显示 **Send** 和 **Receive** 按钮，Buy 和 Exchange 为占位功能，不实现
- 冷钱包完全离线，不依赖网络相关插件（如 share_plus）
- Cardano 地址派生遵循 CIP-1852 硬化路径格式，EVM 遵循 BIP-44 m/44'/60'/0'/0/0
- 多链通过 ChainAdapter 适配器模式扩展，新增链族只需新建适配器 + 注册 ChainConfig
- 代码结构分析必须使用 codegraph MCP（见 `.qoder/rules/codegraph.md`）
- 每个源码目录需维护 README.md（模块文档），各子项目 `lib/README.md` 为文档索引入口

## Agent skills

### Issue tracker

Issue 和规格文档以本地 Markdown 文件形式存储在 `.scratch/<feature>/` 下。详见 `docs/agents/issue-tracker.md`。

### Triage labels

五个标准角色：needs-triage、needs-info、ready-for-agent、ready-for-human、wontfix。详见 `docs/agents/triage-labels.md`。

### Domain docs

单上下文布局：仓库根目录一份 `CONTEXT.md` + `docs/adr/` 存放架构决策。详见 `docs/agents/domain.md`。
