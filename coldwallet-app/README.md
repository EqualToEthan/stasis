# ColdWallet App — Cardano 离线冷钱包

完全离线的 Cardano 冷钱包 Flutter 应用。通过二维码或剪贴板与联网端（coldwallet-watch）交互，完成交易离线签名。

## 功能特性

- 多钱包管理（最多 5 个，独立助记词）
- 助记词生成（安全随机 / 骰子熵）与导入
- CIP-1852 地址派生（m/1852'/1815'/0'/0/0）
- 二维码扫码签名 & 剪贴板粘贴导入签名
- PIN 验证保护签名操作
- Android Keystore 加密存储所有敏感数据

## 项目结构

```
lib/
├── main.dart            # App 入口，路由配置
├── models/              # 数据模型（WalletInfo、ColdExport、ColdImport）
├── screens/             # 页面（首页、钱包管理、扫码签名、交易详情等）
├── services/            # 核心服务（安全存储、钱包管理、交易签名）
└── widgets/             # （暂无，预留）
```

## 路由表

| 路由 | 页面 | 说明 |
|------|------|------|
| `/` | HomeScreen | 首页，钱包选择、扫码签名、粘贴导入入口 |
| `/wallet-setup` | WalletSetupScreen | 钱包管理（创建/导入/备份/删除） |
| `/scan-tx` | ScanTxScreen | 扫描交易二维码 |

## 构建与运行

```bash
# 安装依赖
flutter pub get

# 构建 APK
flutter build apk

# 安装并启动（需连接设备）
flutter install
```

> 注意：本应用完全离线运行，无需网络权限。

## 测试

```bash
flutter test
```

- `test/widget_test.dart` — App 冒烟测试，验证首页正常渲染

## 模块文档

| 模块 | 说明 |
|------|------|
| [models/](lib/models/README.md) | 数据模型：钱包元数据、交易导入导出结构 |
| [screens/](lib/screens/README.md) | 页面层：所有 UI 页面及跳转关系 |
| [services/](lib/services/README.md) | 服务层：安全存储、钱包管理、交易签名 |

## 通信协议

冷钱包与联网端之间的数据交换格式详见 [PROTOCOL.md](../PROTOCOL.md)。

## 技术栈

- Flutter / Dart（SDK ^3.11.1）
- cardano_flutter_sdk — HD 钱包创建和交易签名
- flutter_secure_storage — Android Keystore 加密存储
- bip39_plus — BIP-39 助记词生成
- mobile_scanner / qr_flutter — 二维码扫描与生成
- pointycastle — blake2b 哈希
