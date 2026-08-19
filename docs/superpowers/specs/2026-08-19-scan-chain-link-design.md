# 扫码/导入与首页选中链联动校验设计

## 背景与目标

冷钱包 App 的扫码签名和文件导入流程，目前链识别靠交易 JSON 自带的 `chainId` 字段，
与首页下拉选中的链（`_selectedChainId`）完全解耦。这带来两个问题：

1. 用户可能在选中 EVM Sepolia 时扫到 BSC Testnet 的交易，一路走到签名页才发现链不对。
2. 没有明确提示"当前链与交易链不匹配"，用户体验割裂。

**目标**：让扫码和文件导入两个入口都按首页当前选中的链做前置校验，不匹配直接阻止跳转并提示，
强制用户先切到正确链再操作。

## 需求

- 首页下拉选中的链（`_selectedChainId`）作为"当前链"。
- 扫码入口：扫到的交易 JSON 的链必须与当前链匹配，否则阻止跳转 + SnackBar 提示。
- 文件导入入口（含文件选择和粘贴 JSON 两条路径）：同上校验。
- 不匹配时直接阻止，不进入交易详情页；用户需切换链后重新扫码/导入。
- Cardano 向后兼容：交易 JSON 无 `chainId` 字段时视为 Cardano（`cardano-preview`）。

## 校验规则

在 `lib/services/chain_registry.dart` 增加静态方法：

```dart
/// 从交易 JSON 解析链 ID。
/// 无 chainId 字段时视为 Cardano（'cardano-preview'，向后兼容 ColdExport）。
static String resolveChainId(Map<String, dynamic> json) =>
    (json['chainId'] as String?) ?? 'cardano-preview';
```

匹配判断：`ChainRegistry.resolveChainId(json) == selectedChainId`。

## 改动点（逐文件）

### 1. `lib/services/chain_registry.dart`

- 新增 `resolveChainId(Map<String, dynamic> json)` 静态方法（见上）。

### 2. `lib/screens/scan_tx_screen.dart`

- `ScanTxScreen` 增加构造参数 `final String requiredChainId;`。
- `_onDetect`：在现有 `jsonDecode` 校验之后、`Navigator.pushReplacement` 之前，
  调用 `ChainRegistry.resolveChainId(json)` 与 `widget.requiredChainId` 比对：
  - 匹配 → 跳转 `TxDetailScreen`（保持原逻辑）。
  - 不匹配 → `setState(() => _scanned = false)`（允许重新扫码）+ SnackBar 提示，不跳转。
- 提示文案需用链的友好名称，通过 `ChainRegistry.getConfig(chainId)?.name` 取。

### 3. `lib/screens/home_screen.dart`

- **扫码按钮**：`Navigator.pushNamed(context, '/scan-tx')` 改为
  `Navigator.push(MaterialPageRoute(builder: (_) => ScanTxScreen(requiredChainId: _selectedChainId!)))`。
  - 当 `_selectedChainId == null`（无可用链）时，扫码按钮 `onPressed` 置为 `null`（禁用）。
- **文件导入**：`_parseAndNavigate` 在 `jsonDecode` 之后、`Navigator.push` 之前，
  调用 `ChainRegistry.resolveChainId` 与 `_selectedChainId` 比对：
  - 匹配 → 跳转 `TxDetailScreen`（保持原逻辑）。
  - 不匹配 → SnackBar 提示，不跳转。

### 4. `lib/main.dart`

- 移除 `/scan-tx` 命名路由注册（改用直接 `Navigator.push`）。
- 若命名路由被其他地方引用，需同步排查（codegraph 确认仅 HomeScreen 使用）。

## 提示文案设计

不匹配时 SnackBar 文案：

```
当前选中 {当前链名}，扫到的交易属于 {交易链名}，请切换链后重试
```

- `{当前链名}` = `ChainRegistry.getConfig(_selectedChainId)?.name`
- `{交易链名}` = `ChainRegistry.getConfig(resolveChainId)?.name`，取不到时回退显示 chainId 原值。

示例：
- "当前选中 Ethereum Sepolia，扫到的交易属于 BSC Testnet，请切换链后重试"
- "当前选中 Cardano Preview，扫到的交易属于 Ethereum Sepolia，请切换链后重试"

## 测试计划

### 单元测试（`test/services/`）

- `ChainRegistry.resolveChainId`：
  - 无 `chainId` 字段 → 返回 `'cardano-preview'`。
  - `chainId: 'evm-97'` → 返回 `'evm-97'`。
  - `chainId` 为非 String 类型 → 不崩溃（按协议不会出现，但做防御）。

### Widget 测试（`test/widget_test.dart` 或新建）

- `ScanTxScreen` 传入 `requiredChainId: 'evm-11155111'`，模拟扫码返回 BSC 交易 JSON：
  - 验证不跳转 `TxDetailScreen`。
  - 验证 SnackBar 显示"当前选中 Ethereum Sepolia，扫到的交易属于 BSC Testnet"。
- `ScanTxScreen` 传入 `requiredChainId: 'cardano-preview'`，模拟扫码返回无 chainId 的 Cardano JSON：
  - 验证正常跳转 `TxDetailScreen`（向后兼容匹配）。

## 不在范围内（YAGNI）

- 不做"地址归属校验"（不检查 fromAddress 是否属于当前钱包派生的地址）。本次只做 chainId 级联动。
- 不引入状态管理库（Provider/Riverpod）。选中链通过构造参数传递。
- 不改动 `TxDetailScreen` / `ConfirmSignScreen` / `signForChain` 的链路由逻辑——它们仍按 JSON 的 chainId 工作，
  本联动在前置入口拦截后，后续链路天然一致。
- 不改动 `coldwallet-watch` 端（观察钱包不涉及离线签名）。
