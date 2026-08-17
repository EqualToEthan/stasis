# coldwallet-app — 离线冷钱包

多链离线冷钱包 Flutter 应用。负责助记词管理、多链地址派生（Cardano + EVM）、二维码/文件扫码签名和交易导出。完全离线运行，所有敏感数据通过 Android Keystore 加密存储。

## 模块文档索引

| 模块 | 路径 | 职责 |
|------|------|------|
| models | [models/README.md](models/README.md) | 数据模型 — ChainConfig、ColdExport/ColdImport（Cardano）、EthColdExport/EthColdImport（EVM）、SignResult、WalletInfo |
| services | [services/README.md](services/README.md) | 业务服务 — WalletService（多链地址派生）、TransactionService（多链签名路由）、SecureStorageService、ChainRegistry |
| services/adapters | [services/adapters/README.md](services/adapters/README.md) | 链适配器 — ChainAdapter 接口、CardanoAdapter（CIP-1852）、EvmAdapter（BIP-44 + EIP-155/1559） |
| screens | [screens/README.md](screens/README.md) | UI 页面 — 首页多链地址展示、钱包管理、扫码签名、交易详情、PIN 确认签名、已签名导出 |

## 架构概览

```
用户 → screens/ → services/ → adapters/
                                ├── CardanoAdapter (CIP-1852 + Ed25519 + CBOR)
                                └── EvmAdapter (BIP-44 + secp256k1 + RLP + EIP-155/1559)
```

- **ChainRegistry** 管理 6 条链配置（1 Cardano + 5 EVM），通过 `chainFamily` 路由到对应适配器
- **同一助记词** 派生所有链的地址，助记词仅在签名时从 SecureStorage 加载，用完即释放
- **向后兼容**：无 `chainId` 的 JSON 自动走 Cardano 旧协议
