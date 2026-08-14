# adapters 模块

链适配器层，封装不同链族（Cardano / EVM / Bitcoin）的地址派生、交易解析和离线签名逻辑。每种链族对应一个适配器实现，通过 ChainAdapter 接口统一调用。

## 文件清单

| 文件 | 主要类 | 功能说明 |
|------|--------|----------|
| chain_adapter.dart | ChainAdapter | 链适配器抽象接口，定义 deriveAddress、parseExport、signTransaction 方法 |
| cardano_adapter.dart | CardanoAdapter | Cardano 适配器，CIP-1852 地址派生 + CBOR 交易解析 + Ed25519 签名 |
| evm_adapter.dart | EvmAdapter | EVM 适配器，BIP-44 secp256k1 地址派生 + RLP 交易解析 + EIP-155/EIP-1559 签名 |

## 设计说明

- 所有适配器实现 `ChainAdapter` 接口，通过 `ChainRegistry.adapterFor(chainFamily)` 获取实例
- CardanoAdapter 封装现有 cardano_flutter_sdk 的调用逻辑
- EvmAdapter 内建 BIP-32 HD 密钥派生（HMAC-SHA512）和 RLP 编解码器，通过 web3dart 执行签名
- 新增链族只需创建新的适配器文件并在 ChainRegistry 中注册

## 依赖关系

- **内部依赖**：
  - `models/` — ChainConfig、SignResult、ColdExport、EthColdExport
  - `services/chain_registry.dart` — 适配器实例管理
- **外部依赖**：
  - `cardano_flutter_sdk` / `cardano_dart_types` — Cardano 链（CardanoAdapter）
  - `web3dart` — EVM 链私钥和签名（EvmAdapter）
  - `bip39_plus` — 助记词转 seed（EvmAdapter）
  - `pointycastle` — HMAC-SHA512、blake2b、secp256k1（两个适配器共用）
  - `hex` — 十六进制编码/解码

## 常见修改指引

| 我想... | 修改文件 |
|---------|---------|
| 添加新的链族（如 Bitcoin） | 新建 bitcoin_adapter.dart + ChainRegistry 注册 |
| 添加新的 EVM 链 | 无需修改适配器，只需在 chain_registry.dart 添加 ChainConfig |
| 修改 EVM 密钥派生路径 | evm_adapter.dart — 修改 _derivePrivateKey 中的 indices |
| 修改 Cardano 签名逻辑 | cardano_adapter.dart — 修改 signTransaction 方法 |
| 修改链适配器接口 | chain_adapter.dart — 同步修改所有实现类 |
| 支持 EIP-2930 Access List 交易 | evm_adapter.dart — 在 _signRawUnsignedTransaction 中添加 type 0x01 分支 |
