# Cold Wallet Watch 首页改造实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `coldwallet-watch` 首页从钱包列表改造为单钱包仪表盘，包含钱包切换器、设置入口、余额/地址展示、发送/收款按钮、底部资产列表，并删除独立的 `WalletDetailScreen`。

**Architecture:** 在 `WalletService` 增加当前钱包持久化能力；`HomeScreen` 完全重写为仪表盘并承担原详情页职责；新增 `ReceiveScreen` 展示收款二维码；`app.dart` 调整路由；`WalletDetailScreen` 删除。

**Tech Stack:** Flutter, Dart, flutter_secure_storage, shared_preferences, qr_flutter, cardano_dart_types

---

## File Structure

| 文件 | 操作 | 职责 |
|------|------|------|
| `lib/services/wallet_service.dart` | 修改 | 增加 `getCurrentWallet()` / `setCurrentWallet()` |
| `lib/screens/home_screen.dart` | 重写 | 单钱包仪表盘首页 |
| `lib/screens/receive_screen.dart` | 创建 | 收款二维码/地址展示 |
| `lib/screens/wallet_detail_screen.dart` | 删除 | 功能合并到首页 |
| `lib/app.dart` | 修改 | 移除 `/wallet-detail`，新增 `/receive` |
| `test/widget_test.dart` | 修改 | 更新首页引用 |
| `test/services/wallet_service_test.dart` | 创建 | `getCurrentWallet` 测试 |

---

### Task 1: WalletService 扩展当前钱包管理

**Files:**
- Modify: `lib/services/wallet_service.dart`
- Test: `test/services/wallet_service_test.dart`

- [ ] **Step 1: 查看当前 WalletService 实现**

Read: `lib/services/wallet_service.dart`

- [ ] **Step 2: 完善 WalletService 当前钱包逻辑**

当前 `WalletService` 已经存在 `getCurrentWallet()` 和 `setCurrentWallet(String id)` 方法，但 `getCurrentWallet()` 在 `currentId` 未设置或匹配不到时没有把第一个钱包持久化为当前钱包。请修改 `getCurrentWallet()` 为：

```dart
  Future<WatchWallet?> getCurrentWallet() async {
    final wallets = await getWallets();
    if (wallets.isEmpty) return null;
    final currentId = await _storage.getCurrentWalletId();
    if (currentId != null && currentId.isNotEmpty) {
      final match = wallets.where((w) => w.id == currentId).firstOrNull;
      if (match != null) return match;
    }
    final first = wallets.first;
    await _storage.setCurrentWalletId(first.id);
    return first;
  }
```

`setCurrentWallet(String id)` 保持不变。

- [ ] **Step 3: 创建 WalletService 测试**

Create `test/services/wallet_service_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/services/storage_service.dart';
import 'package:coldwallet_watch/services/wallet_service.dart';

class FakeStorageService implements StorageService {
  List<WatchWallet> _wallets = [];
  String? _currentWalletId;

  @override
  Future<List<WatchWallet>> loadWallets() async => _wallets;

  @override
  Future<void> saveWallets(List<WatchWallet> wallets) async {
    _wallets = wallets;
  }

  @override
  Future<String?> getCurrentWalletId() async => _currentWalletId;

  @override
  Future<void> setCurrentWalletId(String id) async {
    _currentWalletId = id;
  }

  @override
  Future<String> getCurrentNetwork() async => 'preview';

  @override
  Future<void> setCurrentNetwork(String network) async {}

  @override
  Future<String?> getBlockfrostApiKey() async => null;

  @override
  Future<void> setBlockfrostApiKey(String apiKey) async {}

  @override
  Future<void> deleteBlockfrostApiKey() async {}

  @override
  Future<List<String>> getEnabledAssets(String walletId) async => [];

  @override
  Future<void> setEnabledAssets(String walletId, List<String> units) async {}
}

void main() {
  group('WalletService current wallet', () {
    test('returns null when no wallets', () async {
      final storage = FakeStorageService();
      final service = WalletService(storage);
      final wallet = await service.getCurrentWallet();
      expect(wallet, isNull);
    });

    test('returns first wallet and persists it when current id is unset', () async {
      final storage = FakeStorageService();
      final service = WalletService(storage);
      await service.addWallet(
        name: 'A',
        address: 'addr_test1abc',
        network: 'preview',
      );
      final wallet = await service.getCurrentWallet();
      expect(wallet, isNotNull);
      expect(wallet!.name, 'A');
      expect(await storage.getCurrentWalletId(), wallet.id);
    });

    test('returns wallet matching persisted current id', () async {
      final storage = FakeStorageService();
      final service = WalletService(storage);
      await service.addWallet(
        name: 'A',
        address: 'addr_test1abc',
        network: 'preview',
      );
      await service.addWallet(
        name: 'B',
        address: 'addr_test1def',
        network: 'preview',
      );
      final wallets = await service.getWallets();
      final second = wallets[1];
      await service.setCurrentWallet(second.id);
      final current = await service.getCurrentWallet();
      expect(current!.name, 'B');
    });
  });
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd coldwallet-watch; flutter test test/services/wallet_service_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
cd coldwallet-watch
git add lib/services/wallet_service.dart test/services/wallet_service_test.dart
```
（注：当前项目未初始化 git，仅需保存文件即可。）

---

### Task 2: 重写 HomeScreen 为单钱包仪表盘

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: 编写新的 HomeScreen**

将 `lib/screens/home_screen.dart` 完整替换为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/asset_balance.dart';
import '../models/watch_wallet.dart';
import '../services/asset_service.dart';
import '../services/blockfrost_service.dart';
import '../services/storage_service.dart';
import '../services/wallet_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late WalletService _walletService;
  WatchWallet? _currentWallet;
  List<WatchWallet> _wallets = [];
  List<AssetBalance> _assets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final storage = await StorageService.create();
    _walletService = WalletService(storage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallets = await _walletService.getWallets();
      final current = await _walletService.getCurrentWallet();
      if (!mounted) return;
      setState(() {
        _wallets = wallets;
        _currentWallet = current;
      });
      if (current != null) {
        await _loadBalances(current);
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadBalances(WatchWallet wallet) async {
    setState(() => _loading = true);
    try {
      final storage = await StorageService.create();
      final apiKey = await storage.getBlockfrostApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = '请先设置 Blockfrost API Key';
          _loading = false;
        });
        return;
      }
      final blockfrost = BlockfrostService(
        apiKey: apiKey,
        network: wallet.network,
      );
      final assetService = AssetService(blockfrost, storage);
      final assets = await assetService.loadBalances(wallet.address, wallet.id);
      assets.sort((a, b) {
        if (a.isAda && !b.isAda) return -1;
        if (!a.isAda && b.isAda) return 1;
        return (a.displayName ?? a.unit).compareTo(
          b.displayName ?? b.unit,
        );
      });
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _navigateSettings() async {
    await Navigator.pushNamed(context, '/settings');
    _load();
  }

  Future<void> _navigateAddWallet() async {
    final result = await Navigator.pushNamed(context, '/add-wallet');
    if (result == true) _load();
  }

  Future<void> _switchWallet(WatchWallet? wallet) async {
    if (wallet == null) return;
    await _walletService.setCurrentWallet(wallet.id);
    _load();
  }

  Future<void> _copyAddress(String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('地址已复制')));
  }

  String _formatAda(String lovelace) {
    final value = BigInt.parse(lovelace);
    final ada = value / BigInt.from(1000000);
    final remainder = value % BigInt.from(1000000);
    final remainderStr = remainder.toString().padLeft(6, '0');
    final trimmed = remainderStr.replaceAll(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? '$ada' : '$ada.$trimmed';
  }

  String _shortAddress(String address) {
    if (address.length <= 14) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading && _currentWallet == null
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_currentWallet == null) return _buildEmptyState();
    if (_error != null) return _buildError(_error!);
    final wallet = _currentWallet!;
    final adaBalance = _assets
        .where((a) => a.isAda)
        .map((a) => _formatAda(a.quantity))
        .firstOrNull;

    return Column(
      children: [
        _buildAppBar(wallet),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildAddressRow(wallet.address),
                  const SizedBox(height: 24),
                  if (adaBalance != null) _buildMainBalance(adaBalance),
                  if (adaBalance == null) const SizedBox(height: 32),
                  const SizedBox(height: 32),
                  _buildActionButtons(wallet),
                  const SizedBox(height: 32),
                  _buildAssetsHeader(),
                  const SizedBox(height: 8),
                  _buildAssetsList(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(WatchWallet wallet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildWalletSelector(wallet),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: _navigateSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSelector(WatchWallet current) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<WatchWallet>(
        value: current,
        icon: const Icon(Icons.keyboard_arrow_down),
        style: Theme.of(context).textTheme.titleMedium,
        items: [
          ..._wallets.map(
            (w) => DropdownMenuItem(
              value: w,
              child: Text('${w.name} (${w.network.toUpperCase()})'),
            ),
          ),
          const DropdownMenuItem(
            value: null,
            child: Text('+ 管理钱包'),
          ),
        ],
        onChanged: (value) {
          if (value == null) {
            _navigateAddWallet();
          } else {
            _switchWallet(value);
          }
        },
      ),
    );
  }

  Widget _buildAddressRow(String address) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.account_balance_wallet,
            size: 18,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _shortAddress(address),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 20),
          tooltip: '复制地址',
          onPressed: () => _copyAddress(address),
        ),
      ],
    );
  }

  Widget _buildMainBalance(String balance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$balance ADA',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(WatchWallet wallet) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.send,
            label: '发送',
            onTap: () => Navigator.pushNamed(
              context,
              '/send',
              arguments: wallet,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionButton(
            icon: Icons.qr_code,
            label: '收款',
            onTap: () => Navigator.pushNamed(
              context,
              '/receive',
              arguments: wallet,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetsHeader() {
    return Text(
      '代币',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildAssetsList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_assets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Text('暂无资产'),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _assets.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final asset = _assets[index];
        final display = asset.displayName ?? asset.unit;
        final quantity = asset.isAda ? _formatAda(asset.quantity) : asset.quantity;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(display),
          subtitle: asset.isAda ? null : Text(asset.unit, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(quantity),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text('还没有只读钱包', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _navigateAddWallet,
            child: const Text('添加钱包'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (message.contains('API Key'))
              FilledButton(
                onPressed: _navigateSettings,
                child: const Text('去设置'),
              )
            else
              FilledButton(
                onPressed: _load,
                child: const Text('重试'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行 flutter analyze 检查 HomeScreen**

Run: `cd coldwallet-watch; flutter analyze lib/screens/home_screen.dart`
Expected: 无错误

- [ ] **Step 3: 保存文件**

---

### Task 3: 创建 ReceiveScreen 收款页面

**Files:**
- Create: `lib/screens/receive_screen.dart`

- [ ] **Step 1: 编写 ReceiveScreen**

Create `lib/screens/receive_screen.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/watch_wallet.dart';

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = ModalRoute.of(context)?.settings.arguments;
    if (wallet is! WatchWallet) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('无钱包数据'))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('收款')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                '仅接收 ${wallet.network.toUpperCase()} 网络的资产',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: QrImageView(
                    data: wallet.address,
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SelectableText(
                      wallet.address,
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: wallet.address),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('地址已复制')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('复制地址'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行 flutter analyze 检查**

Run: `cd coldwallet-watch; flutter analyze lib/screens/receive_screen.dart`
Expected: 无错误

- [ ] **Step 3: 保存文件**

---

### Task 4: 调整路由并删除 WalletDetailScreen

**Files:**
- Modify: `lib/app.dart`
- Delete: `lib/screens/wallet_detail_screen.dart`

- [ ] **Step 1: 修改 app.dart**

将 `lib/app.dart` 替换为：

```dart
import 'package:flutter/material.dart';

import 'screens/add_wallet_screen.dart';
import 'screens/export_tx_screen.dart';
import 'screens/home_screen.dart';
import 'screens/import_signed_screen.dart';
import 'screens/receive_screen.dart';
import 'screens/send_screen.dart';
import 'screens/settings_screen.dart';

class ColdWalletWatchApp extends StatelessWidget {
  const ColdWalletWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cold Wallet Watch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/add-wallet': (context) => const AddWalletScreen(),
        '/send': (context) => const SendScreen(),
        '/receive': (context) => const ReceiveScreen(),
        '/export-tx': (context) => const ExportTxScreen(),
        '/import-signed': (context) => const ImportSignedScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
```

- [ ] **Step 2: 删除 wallet_detail_screen.dart**

Delete: `lib/screens/wallet_detail_screen.dart`

- [ ] **Step 3: 运行 flutter analyze**

Run: `cd coldwallet-watch; flutter analyze`
Expected: 无错误

---

### Task 5: 更新 widget 测试

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: 更新测试文件**

将 `test/widget_test.dart` 替换为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/app.dart';

void main() {
  testWidgets('App shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ColdWalletWatchApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行 widget 测试**

Run: `cd coldwallet-watch; flutter test test/widget_test.dart`
Expected: PASS

---

### Task 6: 全量测试与构建

- [ ] **Step 1: 运行所有测试**

Run: `cd coldwallet-watch; flutter test`
Expected: 全部通过

- [ ] **Step 2: 运行 flutter analyze**

Run: `cd coldwallet-watch; flutter analyze`
Expected: 无错误、无警告

- [ ] **Step 3: 构建 release APK**

Run: `cd coldwallet-watch; flutter build apk --release`
Expected: 构建成功，输出 `build/app/outputs/flutter-apk/app-release.apk`

- [ ] **Step 4: 安装到模拟器**

Run:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.coldwallet.coldwallet_watch/.MainActivity
```
Expected: Success + Starting intent

---

## Spec Coverage Check

| 设计需求 | 对应任务 |
|----------|----------|
| 左上角钱包切换器 | Task 2 HomeScreen._buildWalletSelector |
| 右上角设置入口 | Task 2 HomeScreen._buildAppBar |
| 中部地址/余额展示 | Task 2 HomeScreen._buildAddressRow / _buildMainBalance |
| 发送/收款按钮 | Task 2 HomeScreen._buildActionButtons |
| 底部代币列表 | Task 2 HomeScreen._buildAssetsList |
| 删除 WalletDetailScreen | Task 4 |
| 新增 ReceiveScreen | Task 3 |
| 当前钱包持久化 | Task 1 WalletService |

## Placeholder Scan

- 无 TBD / TODO / implement later。
- 所有代码步骤均包含完整代码。
- 所有命令均包含预期输出。

## Type Consistency Check

- `WalletService.getCurrentWallet()` / `setCurrentWallet(String id)` 与 Task 1 测试一致。
- `ReceiveScreen` 接收 `WatchWallet` 参数，与 `HomeScreen` 路由调用一致。
- `/send` 路由仍接收 `WatchWallet` 参数，与现有 `SendScreen` 一致。
