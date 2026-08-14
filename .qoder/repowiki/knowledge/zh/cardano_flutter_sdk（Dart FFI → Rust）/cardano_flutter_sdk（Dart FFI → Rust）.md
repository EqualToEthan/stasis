---
kind: external_dependency
name: cardano_flutter_sdk（Dart FFI → Rust）
slug: cardano-flutter-sdk
category: external_dependency
category_hints:
    - sdk_real_api
scope:
    - '**'
---

冷钱包 App 与 watch 端均基于 cardano_flutter_sdk 进行 Cardano 密钥派生、地址生成与交易构建。SDK 通过 Dart FFI 调用底层 Rust/C 实现，避免 JS/WASM 层暴露私钥。
- 冷钱包侧：用于 BIP-39/BIP-32 Ed25519 助记词生成、CIP-1852 密钥派生、交易签名。
- watch 端：用于手动构建 ADA（lovelace）转账 unsigned tx CBOR，再导出给冷钱包签名后回传提交。
- 注意：MVP 中 TxBuilderService 仅支持单一 lovelace 输出，原生代币/NFT 转账会抛出 UnsupportedError。