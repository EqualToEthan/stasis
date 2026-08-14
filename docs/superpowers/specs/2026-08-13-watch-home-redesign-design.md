# Cold Wallet Watch 首页改造设计

## 目标

将 `coldwallet-watch` 的首页从"钱包列表"改造为"单钱包仪表盘"，布局参考用户提供的截图：

- 左上角：钱包切换器（Account 1 ▾）
- 右上角：设置入口
- 中部：当前地址、主余额、发送/收款两个操作按钮
- 底部：代币列表（展示所有链上资产，ADA + native tokens/NFTs）

同时删除独立的 `WalletDetailScreen`，把余额和资产详情合并到首页。

## 架构

改造范围集中在表示层：

- `HomeScreen`：完全重写为仪表盘，承担原 `WalletDetailScreen` 的余额/资产展示职责。
- `ReceiveScreen`（新增）：展示当前地址的收款二维码和地址文本，支持复制。
- `WalletDetailScreen`（删除）：功能合并到 `HomeScreen`。
- `WalletService`：增加 `getCurrentWallet()` / `setCurrentWallet()`，基于 `StorageService.currentWalletId` 维护当前选中钱包。
- `app.dart`：移除 `/wallet-detail` 路由，新增 `/receive` 路由；首页改为 `/`。

数据流保持不变：首页通过 `WalletService` + `AssetService` + `BlockfrostService` 异步加载当前钱包余额和资产列表。

## 组件设计

### HomeScreen

状态：
- `WatchWallet? currentWallet`：当前选中的钱包
- `List<WatchWallet> wallets`：所有钱包，用于切换器
- `List<AssetBalance> assets`：当前钱包资产列表
- `bool loading` / `String? error`：加载状态

生命周期：
- `initState` 中通过 `addPostFrameCallback` 调用 `_load()`，避免 `didChangeDependencies` 重复触发。
- 从设置页返回后重新加载（`Navigator.pushNamed` 后 `await`）。

布局结构（从上到下）：
1. 自定义顶部栏：左侧钱包切换下拉，右侧设置图标。
2. 地址行：头像/网络标识 + 地址截断 + 复制按钮。
3. 主余额：大号 ADA 数量，单位 `ADA`。
4. 操作按钮行：两个等宽卡片按钮——发送、收款。
5. 资产列表标题 + 列表：展示 `unit`、`displayName`、`quantity`；若资产较多可滚动。
6. 空状态：无钱包时居中显示"添加钱包"引导。

### WalletSelector

- 接收 `currentWallet` 和 `wallets`。
- 点击展开 `DropdownButton` 或 `PopupMenuButton`，选择后回调 `onSelected(wallet)`。
- 选项显示钱包名称 + 网络，最后一项为"管理钱包"（跳转到钱包列表/管理页）。

### ReceiveScreen

- 接收 `WatchWallet` 参数。
- 居中展示收款地址的二维码（使用 `qr_flutter`）。
- 地址文本 + 复制按钮。
- 提示：仅接收当前网络（mainnet/preview/preprod）的资产。

### WalletService 扩展

新增方法：

```dart
Future<WatchWallet?> getCurrentWallet();
Future<void> setCurrentWallet(String id);
```

实现逻辑：
- `getCurrentWallet`：读取 `currentWalletId`，从钱包列表中匹配；若无匹配，返回第一个钱包（并持久化）。
- `setCurrentWallet`：写入 `currentWalletId` 到 `SharedPreferences`。

### app.dart 路由调整

- 移除 `/wallet-detail`。
- 新增 `/receive`：`ReceiveScreen`。
- `/send` 仍接收 `WatchWallet` 参数。

## 数据流

1. 用户打开 App。
2. `HomeScreen._load()` 调用 `WalletService.getCurrentWallet()` 得到当前钱包。
3. 如果存在钱包，调用 `AssetService.loadBalances(wallet.address, wallet.id)` 从 Blockfrost 拉取资产。
4. 资产列表返回后按 `unit == 'lovelace'` 置顶，其余按名称排序。
5. 用户点击"发送" → 跳转 `/send` 并传入 `currentWallet`。
6. 用户点击"收款" → 跳转 `/receive` 并传入 `currentWallet`。
7. 用户切换钱包 → 调用 `setCurrentWallet` 并重新加载余额。

## 错误处理

- 未设置 Blockfrost API Key：显示提示"请先设置 API Key"，并提供跳转设置的按钮。
- 网络请求失败：显示错误文本 + 重试按钮。
- 无钱包：显示空状态引导用户添加钱包。

## UI 细节

- 主题：继续使用当前 `ColorScheme.fromSeed(seedColor: Colors.blue)`，深色/浅色跟随系统。
- 地址截断：`0x` 前缀可去掉（Cardano 地址为 `addr1...` 或 `addr_test1...`），显示前 8 后 6。
- 余额格式化：将 lovelace 转换为 ADA（除以 1,000,000），保留 6 位小数。
- 操作按钮：使用 `ElevatedButton` 或 `Container` + `InkWell`，占据屏幕宽度约 45%，图标 + 文字垂直排列。
- 资产列表项：左侧单位/名称，右侧数量，点击可复制数量或显示原始 unit。

## 测试

- 单元测试：`WalletService.getCurrentWallet` 在无钱包、单钱包、多钱包场景下的行为。
- Widget 测试：首页空状态、加载状态、余额展示、发送/收款按钮存在性。
- 集成测试：模拟 Blockfrost 返回余额数据，验证资产列表渲染。

## 不在本次范围

- 法币估值。
- "买入/兑换"按钮（watch-only 无私钥，无需实现）。
- 资产显示管理开关（默认展示全部资产）。
- CIP-30 / dApp 浏览器（已有设计，但不在本次改造范围）。
