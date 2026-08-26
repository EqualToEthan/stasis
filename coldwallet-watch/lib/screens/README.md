# screens 模块

观察钱包的页面层。包含所有用户可见的页面：首页、添加钱包、发送、收款、导出交易、导入签名、设置、质押和治理委托。页面通过 Flutter Navigator 路由跳转，使用 `ModalRoute.settings.arguments` 传递数据。

## 文件清单

| 文件 | 主要类 | 功能说明 |
|------|--------|----------|
| add_wallet_screen.dart | AddWalletScreen | 钱包管理页面，上方展示已有钱包列表（支持重命名和删除），下方提供添加新只读钱包的表单。链类型初始无预选（由扫码自动检测或手动选择），支持 Cardano / EVM，EVM 支持选择具体 chainId |
| export_tx_screen.dart | ExportTxScreen | 导出未签名交易，只保留二维码和 JSON 文本两种导出方式；交易详情（发送方、接收方、金额、手续费等）在 coldwallet-app 签名页展示，本页不再重复 |
| home_screen.dart | HomeScreen | 首页，展示钱包选择器、地址（带链族徽章）、余额（Cardano Blockfrost / EVM 暂不支持）、发送/收款/质押/治理委托入口和资产列表；错误时保留 AppBar，错误内嵌显示 |
| import_signed_screen.dart | ImportSignedScreen | 导入已签名交易，进入后先让用户选择扫码/粘贴 JSON 两种方式，解析 ColdImport 后用 InfoCard 卡片风格展示 TxHash 和签名数据摘要，用户确认后才提交到链上 |
| receive_screen.dart | ReceiveScreen | 收款页面，展示地址二维码和完整地址，支持复制 |
| send_screen.dart | SendScreen | 发起转账，输入收款地址、资产和数量，构建未签名交易 |
| settings_screen.dart | SettingsScreen | 设置页面，根据 `AppConfig.isMainnet` 显示当前网络（Preview/Mainnet）并说明全局开关控制机制，提供 Blockfrost API Key 配置 |
| governance_delegation_screen.dart | GovernanceDelegationScreen | 治理委托只读展示页，显示当前 stake key 的治理委托状态；本应用当前仅支持默认弃权（abstain），弃权证书随质押交易自动附带（ADR 0004），用户无感知，本页面不提供操作按钮 |
| staking_screen.dart | StakingScreen | 质押页面，用 InfoCard 展示质押状态（注册状态、当前质押池、可提取奖励），提供质押、提取奖励、解除注册三种操作；已质押时质押面板只读展示当前质押池信息；DRep 弃权随质押交易自动附带（ADR 0004），用户无感知，提取奖励面板不再做 DRep 门控（异常状态由链上报错兜底） |

## 依赖关系

- **内部依赖**：
  - `models/` — WatchWallet、AssetBalance、ColdExport、ColdImport、Certificate
  - `services/` — WalletService、BlockfrostService、AssetService、StorageService、TxBuilderService、StakeTransactionBuilder
  - **widgets/** — QRDisplay、QRScanner、InfoCard
- **外部依赖**：qr_flutter、mobile_scanner

## 页面跳转关系

```
HomeScreen → AddWalletScreen（钱包管理 + 添加）
HomeScreen → SendScreen → ExportTxScreen → ImportSignedScreen（完整发送流程）
HomeScreen → ReceiveScreen（收款）
HomeScreen → StakingScreen → ExportTxScreen → ImportSignedScreen（质押流程）
HomeScreen → GovernanceDelegationScreen（治理委托展示）
HomeScreen → SettingsScreen（设置）
```

## 常见修改指引

| 我想... | 修改文件 |
|---------|---------|
| 修改首页布局或显示内容 | home_screen.dart — 修改 _buildBody 及各 _buildXxx 方法 |
| 添加新的首页操作按钮 | home_screen.dart — 在 _buildActionButtons 中添加 _ActionButton |
| 修改发送页面的表单字段 | send_screen.dart — 修改 build 方法中的 TextField |
| 添加新的交易导出方式 | export_tx_screen.dart — 添加新的按钮和处理函数 |
| 修改添加钱包的链选项 | add_wallet_screen.dart — 修改 _evmChainOptions 常量或链族下拉 items |
| 修改重命名校验逻辑 | add_wallet_screen.dart — 修改 _showRenameDialog 中的非空和重名校验 |
| 修改地址验证规则 | add_wallet_screen.dart — 修改 _save 方法中的校验逻辑（实际校验在 WalletService） |
| 修改设置页面网络文案 | settings_screen.dart — 修改 build 方法中网络信息的展示文本 |
| 修改设置页面选项 | settings_screen.dart — 在 build 方法中添加新的设置项 |
| 修改已委托状态下的委托面板 | staking_screen.dart — 修改 _buildDelegatePanel 中 poolId 判断逻辑 |
| 修改治理委托状态展示 | governance_delegation_screen.dart — 修改 _buildStatusCard 中状态推导逻辑 |
| 修改质押交易的弃权证书 | services/stake_transaction_builder.dart — 修改 buildDelegate 中 voteDelegation 证书构建 |
| 修改导入签名结果的默认入口 | import_signed_screen.dart — 修改 _buildMethodSelector 或 _buildScanner |
| 修改提交前确认对话框内容 | import_signed_screen.dart — 修改 _confirmAndSubmit 方法中的 AlertDialog 内容 |
