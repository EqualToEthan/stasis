# 多链冷钱包

多链气隙（air-gap）冷钱包系统，由离线签名端（coldwallet-app）和联网观察端（coldwallet-watch）组成，通过 JSON 协议交换数据完成链上交易。

## 应用身份

**Stasis**:
两个应用的统一品牌名称。
_Avoid_: Cold Wallet App、冷钱包 App（仅用于内部代码引用时）

**冷钱包（coldwallet-app）**:
完全离线的签名端，持有助记词和私钥，负责地址派生和交易签名。绝不联网。
_Avoid_: 冷端、离线端

**观察钱包（coldwallet-watch）**:
联网的热端，仅持有公钥地址，负责查看余额、构建未签名交易、提交已签名交易。不包含任何私钥或助记词。
_Avoid_: 热钱包、联网端、watch app

## 数据流

**ColdExport**:
未签名交易的数据载体，由观察钱包构建，传递给冷钱包进行签名。Cardano 使用 CBOR 编码交易体，EVM 使用 RLP 编码的 EIP-1559 交易 hex。
_Avoid_: 未签名交易（口语可用，代码中必须用 ColdExport）

**ColdImport**:
已签名交易的数据载体，由冷钱包生成，传递回观察钱包提交到链上。
_Avoid_: 已签名交易（口语可用，代码中必须用 ColdImport）

**EthColdExport**:
EVM 链族的未签名交易数据载体，与 Cardano 的 ColdExport 平行。包含 chainId 字段以区分具体 EVM 链。
_Avoid_: EVM ColdExport、以太坊交易

**传输通道**:
冷钱包与观察钱包之间的数据交换方式，支持二维码和文件导出/导入两种。
_Avoid_: 通信方式、同步

## 链体系

**链族（chain family）**:
具有相同密码学和交易模型的一组链的归类。当前支持 `cardano` 和 `evm`，预留 `bitcoin`。
_Avoid_: 链类型、链类别

**链配置（ChainConfig）**:
描述一条链的静态元数据：chainId、chainFamily、显示名称、网络标识。所有配置在 ChainRegistry 中硬编码，不可运行时修改或添加。
_Avoid_: 链信息、网络配置

**链适配器（ChainAdapter）**:
链族级别的抽象接口，封装地址派生、交易解析和签名的链特有逻辑。当前实现：CardanoAdapter、EvmAdapter。
_Avoid_: 链服务、链处理器

**链注册中心（ChainRegistry）**:
管理所有受支持链配置的静态注册表，提供 chainId → ChainConfig 和 chainFamily → ChainAdapter 的查找。
_Avoid_: 链管理器

## 钱包

**助记词（mnemonic）**:
BIP-39 标准的 12 或 24 个英语单词序列，是钱包的根密钥。支持三种生成方式：SDK 随机生成、物理骰子熵源、手动导入。
_Avoid_: 种子词、恢复短语

**密码短语（passphrase）**:
BIP-39 可选的第 25 个词，与助记词共同决定钱包地址。设置后相同助记词会产生完全不同的地址。留空即不使用。
_Avoid_: 密码、口令、PIN

**PIN**:
应用级访问控制密码（数字），用于每次签名前的身份验证。全局共享，与助记词/密码短语无关。
_Avoid_: 密码、锁屏密码

**WalletInfo**:
钱包的元数据记录（id、名称、创建时间），不含任何敏感信息。存储在 Secure Storage 中与助记词分离。
_Avoid_: 钱包、钱包对象

**WatchWallet**:
观察钱包中保存的只读钱包记录，仅含公钥地址和元数据，可附带 Cardano stake address。
_Avoid_: 观察地址、监控钱包

## 资产与交易

**TxSummary（交易摘要）**:
冷钱包用户在签名前确认交易内容的人类可读摘要，包含发送方、接收方、资产列表和手续费。
_Avoid_: 交易详情、交易信息

**AssetBalance**:
某个地址下一种资产的余额记录，包含资产标识（unit）、数量、显示名称。ADA 的 unit 为 `lovelace`，原生代币为 policyId+assetName 的 hex。
_Avoid_: 代币余额、资产信息

**Certificate（证书）**:
Cardano 质押操作的链上声明，类型包括 stakeRegistration、stakeDelegation、stakeDeregistration。
_Avoid_: 质押操作、质押交易

**Stake Address**:
Cardano 质押地址，与支付地址分离。观察钱包通过合并地址 QR（paymentAddress + stakeAddress）一次性导入。
_Avoid_: 奖励地址、质押公钥
