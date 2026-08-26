# ColdWallet Watch — Cardano 联网观察钱包

Cardano 冷钱包的联网只读客户端（Flutter）。用于查看余额、构建交易，并通过二维码/剪贴板与离线冷钱包交互完成签名和提交。

## 功能特性

- 多钱包管理（只读地址，不含私钥）
- 通过 Blockfrost API 查询地址余额和资产
- 构建 ADA 转账交易（迭代估算手续费）
- 两种主要方式导出未签名交易（二维码 / 复制 JSON 文本）
- 两种主要方式导入已签名交易（扫码 / 粘贴 JSON）
- 提交已签名交易到链上

## 项目结构

```
lib/
├── main.dart            # App 入口
├── app.dart             # MaterialApp 根组件，路由配置
├── models/              # 数据模型（WatchWallet、AssetBalance、ColdExport、ColdImport）
├── screens/             # 页面（首页、发送、收款、导出、导入、设置等）
├── services/            # 业务服务（Blockfrost、存储、钱包管理、交易构建、资产查询）
└── widgets/             # 可复用 UI 组件（二维码显示/扫描）
```

## 路由表

| 路由 | 页面 | 说明 |
|------|------|------|
| `/` | HomeScreen | 首页，钱包选择器、余额、发送/收款入口 |
| `/add-wallet` | AddWalletScreen | 添加只读钱包 |
| `/send` | SendScreen | 发起转账 |
| `/receive` | ReceiveScreen | 收款地址二维码 |
| `/export-tx` | ExportTxScreen | 导出未签名交易 |
| `/import-signed` | ImportSignedScreen | 导入已签名交易并提交 |
| `/settings` | SettingsScreen | 网络和 API Key 设置 |

## 构建与运行

```bash
# 安装依赖
flutter pub get

# 构建 APK
flutter build apk

# 安装并启动（需连接设备）
flutter install
```

## 测试

```bash
flutter test
```

- `test/widget_test.dart` — App 冒烟测试，验证首页正常渲染
- `test/services/wallet_service_test.dart` — WalletService 单元测试（钱包增删、当前钱包切换）

## 模块文档

| 模块 | 说明 |
|------|------|
| [models/](lib/models/README.md) | 数据模型：只读钱包、资产余额、交易导入导出 |
| [screens/](lib/screens/README.md) | 页面层：所有 UI 页面及跳转关系 |
| [services/](lib/services/README.md) | 服务层：Blockfrost API、存储、钱包管理、交易构建 |
| [widgets/](lib/widgets/README.md) | 可复用组件：二维码显示和扫描 |

## 通信协议

与离线冷钱包之间的数据交换格式详见 [PROTOCOL.md](../PROTOCOL.md)。

## 技术栈

- Flutter / Dart（SDK ^3.11.1）
- cardano_flutter_sdk / cardano_dart_types — Cardano 交易构建
- http — Blockfrost REST API 调用
- shared_preferences — 明文本地存储
- flutter_secure_storage — API Key 加密存储
- mobile_scanner / qr_flutter — 二维码扫描与生成
- intl — 国际化格式化
