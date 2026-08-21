# coldwallet-watch — 联网观察钱包

联网观察钱包 Flutter 应用。用于查看多链余额、构建未签名交易，并通过二维码/文件与冷钱包交换已签名交易数据。网络固定为 Cardano preview testnet，不允许网络切换。

## 模块文档索引

| 模块 | 路径 | 职责 |
|------|------|------|
| models | [models/README.md](models/README.md) | 数据模型 — WatchWallet、AssetBalance、ColdExport/ColdImport |
| services | [services/README.md](services/README.md) | 业务服务 — BlockfrostService（链上数据查询）、WalletService、AssetService、TxBuilderService、StakeTransactionBuilder |
| screens | [screens/README.md](screens/README.md) | UI 页面 — 首页余额展示、添加钱包、发送交易、接收地址、未签名交易导出、已签名导入 |
| widgets | [widgets/README.md](widgets/README.md) | 可复用组件 |

## 架构概览

```
用户 → screens/ → services/
                    ├── BlockfrostService (HTTP API → 链上数据)
                    ├── WalletService (地址管理 + 存储)
                    ├── AssetService (资产查询 + 过滤)
                    ├── TxBuilderService (ADA 转账交易构建)
                    └── StakeTransactionBuilder (质押交易构建)
```

- 与冷钱包通过 JSON 协议交换数据（`ColdExport` / `ColdImport`）
- 传输方式：二维码扫描 + 文件导出/导入
- 资产展示仅显示用户启用的资产，避免不必要查询
