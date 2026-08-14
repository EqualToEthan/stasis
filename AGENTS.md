# Cardano 冷钱包项目

## 项目概述

Cardano 冷钱包系统，包含两个 Flutter 应用：

- **coldwallet-app**：离线冷钱包，负责助记词管理、CIP-1852 地址派生、二维码扫码签名与交易文件导入导出
- **coldwallet-watch**：联网观察钱包，用于查看余额、构建未签名交易，并通过扫码/文件导入导出已签名交易

两端通过 JSON 格式交换数据（`ColdExport` / `ColdImport`），传输方式支持二维码和文件导出/导入。详见 [PROTOCOL.md](PROTOCOL.md)。

## 网络配置

网络固定为 **Cardano preview testnet**，不允许网络切换 UI 或逻辑。

## 项目结构

```
coldwallet/
├── coldwallet-app/          # 离线冷钱包 Flutter 应用
│   ├── lib/
│   │   ├── models/          # 数据模型（wallet_info, cold_export, cold_import）
│   │   ├── screens/         # UI 页面（wallet_setup, home, confirm_sign, scan_tx 等）
│   │   ├── services/        # 业务服务（wallet, transaction, secure_storage）
│   │   └── widgets/         # 可复用组件
│   └── test/                # 测试
├── coldwallet-watch/        # 联网观察钱包 Flutter 应用
│   ├── lib/
│   │   ├── models/          # 数据模型（watch_wallet, asset_balance, cold_export, cold_import）
│   │   ├── screens/         # UI 页面（home, add_wallet, send, receive, export_tx 等）
│   │   ├── services/        # 业务服务（blockfrost, wallet, asset）
│   │   └── widgets/         # 可复用组件
│   └── test/                # 测试
├── docs/superpowers/        # 设计文档和开发计划
├── .agents/skills/          # Cardano 开发相关 Skill
└── PROTOCOL.md              # 冷热钱包通信协议定义
```

## 验证命令

每次代码编辑后，必须运行以下验证：

```bash
# Dart 静态分析（在对应子项目目录执行）
cd coldwallet-app && flutter analyze
cd coldwallet-watch && flutter analyze

# 运行测试
cd coldwallet-app && flutter test
cd coldwallet-watch && flutter test

# 构建检查（Debug APK）
cd coldwallet-app && flutter build apk --debug
cd coldwallet-watch && flutter build apk --debug
```

最小验证流程：编辑代码后至少运行 `flutter analyze`，确认无错误和警告。涉及 UI 改动时还需运行 `flutter test`。

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
- 地址派生遵循 CIP-1852 硬化路径格式
- 代码结构分析必须使用 codegraph MCP（见 `.qoder/rules/codegraph.md`）
- 每个源码目录需维护 README.md（模块文档）
