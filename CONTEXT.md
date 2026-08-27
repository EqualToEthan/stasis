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
冷钱包与观察钱包之间的数据交换方式，支持二维码和剪贴板（复制/粘贴 JSON）两种。
_Avoid_: 通信方式、同步、文件传输

## 链体系

**链族（chain family）**:
具有相同密码学和交易模型的一组链的归类。当前支持 `cardano` 和 `evm`，预留 `bitcoin`。
_Avoid_: 链类型、链类别

**链配置（ChainConfig）**:
描述一条链的静态元数据：chainId、chainFamily、显示名称、网络标识、evmChainId。定义在 coldwallet-protocol 中，由 ChainRegistry 维护测试网和主网两组配置，运行时由 AppConfig 决定激活哪组。
_Avoid_: 链信息、网络配置

**AppConfig**:
coldwallet-protocol 中的全局网络开关（`static bool isMainnet`）。决定 ChainRegistry 激活测试网还是主网配置组。改这一个字段即可切换全局网络，两个 app 同步生效。
_Avoid_: 网络配置、环境配置

**链注册中心（ChainRegistry）**:
管理所有受支持链配置的静态注册表，提供 chainId → ChainConfig 查找。定义在 coldwallet-protocol 中，维护测试网和主网两组配置，按 AppConfig.isMainnet 选组。两个 app 共享。
_Avoid_: 链管理器

**适配器注册表（AdapterRegistry）**:
coldwallet-app 专属的链适配器查找表，提供 chainFamily → ChainAdapter 映射。从 ChainRegistry 拆出，因适配器含私钥派生和签名逻辑，不放入共享包。
_Avoid_: 链适配器管理器

**链适配器（ChainAdapter）**:
链族级别的抽象接口，封装地址派生、交易解析和签名的链特有逻辑。当前实现：CardanoAdapter、EvmAdapter。
_Avoid_: 链服务、链处理器

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
观察钱包中保存的只读钱包记录，仅含公钥地址和元数据。Cardano 钱包附带 stake address，绑定特定链（chainId 区分 preview/mainnet）；EVM 钱包仅保存地址，不绑定链——同一个地址天然存在于所有 EVM 链上，链是查看维度而非身份的一部分。
_Avoid_: 观察地址、监控钱包

## EVM 地址身份

**地址即身份（address-as-identity）**:
EVM 链族中，同一个私钥在所有 EVM 链上派生出完全相同的地址。因此观察钱包中一个 EVM 地址 = 一个钱包条目，链只是查看余额的维度。用户添加 EVM 钱包时无需选择链，首页通过链下拉列表展示该地址在各链上的资产。Cardano 不受此概念影响——不同网络的 Cardano 地址不同，仍按一条链一个条目管理。
_Avoid_: EVM 多链钱包、跨链钱包（仅用于内部讨论时）

## 资产与交易

**原生代币（Native Token）**:
链的原生加密资产，用于支付网络手续费（Gas）。Cardano 为 ADA，EVM 链族为 ETH、BNB、MATIC 等。原生代币没有合约地址，通过账户余额接口查询。
_Avoid_: 主币、公链币

**ERC-20 代币**:
EVM 链上同质化代币标准，由智能合约发行，通过合约地址唯一标识。USDT、USDC 等常见稳定币均为 ERC-20。本项目中的 EVM 资产查询默认覆盖 ERC-20，不包含 NFT。
_Avoid_: 代币、以太坊代币

**合约地址（Contract Address）**:
EVM 链上部署智能合约的地址，格式为 `0x` 前缀的 20 字节 hex。ERC-20 代币以合约地址作为资产标识；观察钱包中用户通过输入合约地址手动添加代币。
_Avoid_: 合约、Token 合约

**TxSummary（交易摘要）**:
冷钱包用户在签名前确认交易内容的人类可读摘要，包含发送方、接收方、资产列表和手续费。
_Avoid_: 交易详情、交易信息

**AssetBalance**:
某个地址下一种资产的余额记录，包含资产标识（unit）、数量、显示名称。ADA 的 unit 为 `lovelace`，Cardano 原生代币为 policyId+assetName 的 hex；EVM 资产使用独立的 `EvmAssetBalance` 模型表示。
_Avoid_: 代币余额、资产信息

**Certificate（证书）**:
Cardano 质押与治理操作的链上声明，类型包括 stakeRegistration、stakeDelegation、stakeDeregistration、voteDelegation。
_Avoid_: 质押操作、质押交易

**治理委托（DRep delegation）**:
把 stake key 的治理投票权委托给 DRep、弃权（abstain）或表示不信任（no-confidence）的链上操作。Conway 时代起是奖励提取的前置条件：ledger 检查奖励账户在本交易**之前**的委托状态，因此治理委托证书与奖励提取必须在两笔交易中完成（链上规则，无法绕过）。
_Avoid_: DRep 委托、投票委托

**弃权（abstain）**:
治理委托的一种形式，对治理提案投弃权票（既不赞成也不反对），同时满足奖励提取的治理委托前置条件。本项目当前唯一支持的治理委托形式——系统在质押交易时自动附带弃权证书，用户无感知；不提供选择具体 DRep 的界面，后续再规划。
_Avoid_: 不投票、空委托

**Stake Address**:
Cardano 质押地址，与支付地址分离。观察钱包通过合并地址 QR（paymentAddress + stakeAddress）一次性导入。