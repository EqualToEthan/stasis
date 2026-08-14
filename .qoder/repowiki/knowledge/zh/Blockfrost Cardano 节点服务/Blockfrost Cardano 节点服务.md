---
kind: external_dependency
name: Blockfrost Cardano 节点服务
slug: blockfrost
category: external_dependency
category_hints:
    - vendor_identity
    - client_constraint
scope:
    - '**'
---

项目通过 Blockfrost 作为 Cardano 链上数据与交易提交的后端。冷钱包 App（coldwallet-app）负责离线签名，热观察端 App（coldwallet-watch）在设置页由用户填入自己的 Blockfrost Project ID，并以该 Key 查询余额、UTxO、提交已签名交易。
- 网络绑定约束：preview 网络的 Project ID 只能查 preview，mainnet 的 Project ID 只能查 mainnet；切换网络时必须同时更换对应网络的 Project ID，否则会返回 403。
- 当前 MVP 仅使用 Blockfrost 做余额/UTxO 查询和 submitTx，未集成 dApp 浏览器或 CIP-30 注入。
- 密钥存储策略：Blockfrost API Key 经 flutter_secure_storage 加密保存，地址/名称等公开信息用 SharedPreferences 明文存储。