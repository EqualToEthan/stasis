import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import '../models/asset_balance.dart';
import '../models/watch_wallet.dart';
import '../services/asset_service.dart';
import '../services/blockfrost_service.dart';
import '../services/storage_service.dart';
import '../services/wallet_service.dart';

/// 观察钱包首页
///
/// 展示钱包选择器、地址、ADA 余额、发送/收款入口和资产列表。
/// 通过 Blockfrost API 查询链上余额，支持下拉刷新。
class HomeScreen extends StatefulWidget {
  /// 可选的 StorageService 注入，主要用于测试。
  final StorageService? storageService;

  /// 可选的 BlockfrostService 注入，主要用于测试。
  final BlockfrostService? blockfrostService;

  const HomeScreen({super.key, this.storageService, this.blockfrostService});

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
    final storage = widget.storageService ?? await StorageService.create();
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
    // EVM 链暂不支持余额查询
    if (wallet.isEvm) {
      if (!mounted) return;
      setState(() {
        _assets = [];
        _loading = false;
        _error = null;
      });
      return;
    }

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
      final blockfrost =
          widget.blockfrostService ??
          BlockfrostService(
            apiKey: apiKey,
            network: AppConfig.isMainnet ? 'mainnet' : 'preview',
          );
      final assetService = AssetService(blockfrost, storage);
      final assets = await assetService.loadBalances(wallet.address, wallet.id);
      assets.sort((a, b) {
        if (a.isAda && !b.isAda) return -1;
        if (!a.isAda && b.isAda) return 1;
        return (a.displayName ?? a.unit).compareTo(b.displayName ?? b.unit);
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
    await Navigator.pushNamed(context, '/add-wallet');
    // 始终刷新：用户可能在管理页面添加、删除或重命名钱包
    _load();
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
    final ada = value ~/ BigInt.from(1000000);
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
    final wallet = _currentWallet!;

    // 错误时保留顶部 AppBar（钱包选择器 + 设置），错误内嵌显示
    if (_error != null) {
      return Column(
        children: [
          _buildAppBar(wallet),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: _navigateSettings,
                          child: const Text('去设置'),
                        ),
                        const SizedBox(width: 16),
                        FilledButton(onPressed: _load, child: const Text('重试')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

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
                  _buildAddressRow(wallet),
                  const SizedBox(height: 24),
                  if (wallet.isCardano && adaBalance != null)
                    _buildMainBalance(adaBalance),
                  if (wallet.isCardano && adaBalance == null)
                    const SizedBox(height: 32),
                  if (wallet.isEvm) _buildEvmBalancePlaceholder(),
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
          _buildWalletSelector(wallet.id),
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

  Widget _buildWalletSelector(String currentId) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: currentId,
        icon: const Icon(Icons.keyboard_arrow_down),
        style: Theme.of(context).textTheme.titleMedium,
        items: [
          ..._wallets.map(
            (w) => DropdownMenuItem(value: w.id, child: Text(w.name)),
          ),
          const DropdownMenuItem(value: '_manage', child: Text('+ 管理钱包')),
        ],
        onChanged: (value) {
          if (value == null || value == '_manage') {
            _navigateAddWallet();
          } else {
            final selected = _wallets.where((w) => w.id == value).firstOrNull;
            if (selected != null) _switchWallet(selected);
          }
        },
      ),
    );
  }

  Widget _buildAddressRow(WatchWallet wallet) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: wallet.isEvm
                          ? Colors.blue.shade100
                          : Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      wallet.isEvm ? 'EVM' : 'Cardano',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: wallet.isEvm
                            ? Colors.blue.shade800
                            : Colors.teal.shade800,
                      ),
                    ),
                  ),
                  if (wallet.chainId != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      wallet.chainId!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _shortAddress(wallet.address),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 20),
          tooltip: '复制地址',
          onPressed: () => _copyAddress(wallet.address),
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
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildActionButtons(WatchWallet wallet) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.send,
                label: '发送',
                onTap: wallet.isCardano
                    ? () => Navigator.pushNamed(
                        context,
                        '/send',
                        arguments: wallet,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActionButton(
                icon: Icons.qr_code,
                label: '收款',
                onTap: () =>
                    Navigator.pushNamed(context, '/receive', arguments: wallet),
              ),
            ),
          ],
        ),
        if (wallet.stakeAddress != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.how_to_vote,
                  label: '质押',
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/staking',
                    arguments: wallet,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ActionButton(
                  icon: Icons.account_balance,
                  label: '治理委托',
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/governance-delegation',
                    arguments: wallet,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// EVM 链余额占位提示
  Widget _buildEvmBalancePlaceholder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'EVM 链余额查询暂不支持',
              style: TextStyle(color: Colors.orange.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsHeader() {
    return Text(
      '代币',
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final asset = _assets[index];
        final display = asset.displayName ?? asset.unit;
        final quantity = asset.isAda
            ? _formatAda(asset.quantity)
            : asset.quantity;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(display),
          subtitle: asset.isAda
              ? null
              : Text(asset.unit, maxLines: 1, overflow: TextOverflow.ellipsis),
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap != null ? 1.0 : 0.4,
      child: Material(
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
      ),
    );
  }
}
