# screens 模块

冷钱包的页面层。包含所有用户可见的页面：首页、钱包管理、扫码签名、交易详情、PIN 确认签名、骰子熵收集和已签名交易导出。支持 Cardano 和 EVM 多链交易的扫码、详情展示和签名路由。页面通过 Flutter Navigator 路由跳转和 MaterialPageRoute 传参。

## 文件清单

| 文件 | 主要类 | 功能说明 |
|------|--------|----------|
| confirm_sign_screen.dart | ConfirmSignScreen | PIN 验证并签名交易，支持 Cardano 和 EVM 多链签名路由 |
| dice_entropy_screen.dart | DiceEntropyScreen | 骰子熵收集，掷物理骰子 256 次收集真随机熵生成 BIP-39 助记词 |
| export_signed_screen.dart | ExportSignedScreen | 已签名交易导出，展示交易哈希、二维码，支持复制和文件导出 |
| home_screen.dart | HomeScreen | 首页，钱包选择器和操作入口（扫码签名、文件导入、钱包管理）。扫码/导入时从 JSON 自动检测链类型，无需显式链选择器 |
| scan_tx_screen.dart | ScanTxScreen | 扫描交易二维码，从 JSON 自动检测链类型并校验是否为已注册链，通过后跳转交易详情页 |
| tx_detail_screen.dart | TxDetailScreen | 交易详情，根据链类型展示 Cardano 或 EVM 交易摘要；Cardano 质押交易额外显示押金信息（正数=注册押金，负数=退回押金） |
| wallet_setup_screen.dart | WalletSetupScreen | 钱包管理，支持创建/掷骰子/导入钱包，创建流程包含命名 → BIP-39 密码短语（可选）→ 助记词备份 → PIN 设置。展开视图展示多链地址（每行含 QR 和复制按钮）、Cardano Stake Address、助记词（受 PIN 保护，验证通过后显示，折叠后重置）。每个卡片支持重命名和删除 |

## 依赖关系

- **内部依赖**：
  - `models/` — ColdExport、ColdImport、WalletInfo、ChainConfig、EthColdExport
  - `services/` — WalletService、TransactionService、ChainRegistry
- **外部依赖**：mobile_scanner、qr_flutter、file_picker、flutter/services（Clipboard、HapticFeedback）

## 页面跳转关系

```
HomeScreen → ScanTxScreen → TxDetailScreen → ConfirmSignScreen → ExportSignedScreen（完整签名流程）
HomeScreen → WalletSetupScreen（钱包管理）
WalletSetupScreen → DiceEntropyScreen（骰子熵生成助记词）
HomeScreen（文件导入）→ TxDetailScreen → ConfirmSignScreen → ExportSignedScreen
```

## 常见修改指引

| 我想... | 修改文件 |
|---------|---------|
| 修改首页布局或按钮样式 | home_screen.dart — 修改 _buildActionButton 和 build 方法 |
| 修改多链地址展示逻辑 | wallet_setup_screen.dart — 修改 _buildWalletCard 中的展开视图 |
| 修改地址二维码展示逻辑 | wallet_setup_screen.dart — Cardano 链修改 _showCombinedQrDialog，EVM 链修改 _showAddressQrDialog，链选择逻辑在 _showAddressQr |
| 添加新的钱包创建方式 | wallet_setup_screen.dart — 在 _showAddWalletSheet 中添加选项 |
| 修改钱包重命名逻辑 | wallet_setup_screen.dart — 修改 _showRenameDialog 中的校验和调用逻辑 |
| 修改 BIP-39 密码短语输入 | wallet_setup_screen.dart — 创建流程修改 _showPassphraseDialog，导入流程修改 _buildImportForm 中的 passphrase TextField |
| 修改交易详情的显示字段 | tx_detail_screen.dart — 修改 _buildInfoCard 调用 |
| 添加新链类型的详情展示 | tx_detail_screen.dart — 在 _buildSummary 中添加链类型分支 |
| 修改 PIN 输入界面 | confirm_sign_screen.dart — 修改 build 方法中的 TextField |
| 修改骰子熵的收集规则 | dice_entropy_screen.dart — 修改 _onRoll 和 _totalRolls |
| 修改已签名交易的导出方式 | export_signed_screen.dart — 添加新的导出按钮和处理函数 |
| 修改二维码扫描的 UI 框 | scan_tx_screen.dart — 修改 Positioned 中的扫描框样式 |
