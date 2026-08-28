import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import '../models/asset_balance.dart';
import '../models/evm_asset_balance.dart';
import '../models/watch_wallet.dart';
import '../services/asset_service.dart';
import '../services/blockfrost_service.dart';
import '../services/evm_asset_service.dart';
import '../services/evm_rpc_service.dart';
import '../services/storage_service.dart';
import '../services/wallet_service.dart';

/// 观察钱包首页
///
/// 展示钱包选择器、地址、余额、发送/收款入口和资产列表。
/// Cardano 通过 Blockfrost API 查询链上余额；
/// EVM 通过链下拉列表切换，显示当前链的资产余额，后台预加载其他链。
/// 支持下拉刷新。
class HomeScreen extends StatefulWidget {
  /// 可选的 StorageService 注入，主要用于测试。
  final StorageService? storageService;

  /// 可选的 BlockfrostService 注入，主要用于测试。
  final BlockfrostService? blockfrostService;

  /// 可选的 EvmAssetService 注入，主要用于测试。
  final EvmAssetService? evmAssetService;

  const HomeScreen({
    super.key,
    this.storageService,
    this.blockfrostService,
    this.evmAssetService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late WalletService _walletService;
  WatchWallet? _currentWallet;
  List<WatchWallet> _wallets = [];
  List<AssetBalance> _assets = [];
  Map<String, List<EvmAssetBalance>> _evmAssetsByChain = {};

  /// 每条 EVM 链最近一次查询失败的错误信息，成功后清除。
  final Map<String, String> _evmChainErrors = {};

  /// 正在查询中的 EVM 链集合，用于在余额区显示加载指示器。
  final Set<String> _evmLoadingChains = {};
  String? _selectedEvmChainId;
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
    setState(() => _loading = true);
    try {
      final storage = widget.storageService ?? await StorageService.create();

      if (wallet.isEvm) {
        if (_selectedEvmChainId == null) {
          _selectedEvmChainId = AppConfig.isMainnet ? 'evm-56' : 'evm-97';
        }
        await _loadEvmChainBalances(wallet.address, _selectedEvmChainId!);
        // 后台预加载其他链
        final evmConfigs = ChainRegistry.configsForFamily('evm');
        for (final config in evmConfigs) {
          if (config.chainId != _selectedEvmChainId &&
              !_evmAssetsByChain.containsKey(config.chainId)) {
            _loadEvmChainBalances(wallet.address, config.chainId);
          }
        }
        if (!mounted) return;
        setState(() {
          _assets = [];
          _loading = false;
          _error = null;
        });
        return;
      }

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
        _evmAssetsByChain = {};
        _selectedEvmChainId = null;
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

  /// 加载指定 EVM 链的资产余额并缓存。
  ///
  /// 使用 [widget.evmAssetService]（若注入）或新建实例查询。
  /// 查询结果缓存在 [_evmAssetsByChain] 中，切换链时优先使用缓存。
  /// 单链失败不抛出、不影响其他链，但会记录到 [_evmChainErrors]，
  /// 由余额区行内显示错误态与重试按钮，与“余额为 0”区分（ADR-0008 缺陷 D2）。
  Future<void> _loadEvmChainBalances(String address, String chainId) async {
    final storage = widget.storageService ?? await StorageService.create();
    final evmService =
        widget.evmAssetService ?? EvmAssetService(EvmRpcService(), storage);
    setState(() {
      _evmLoadingChains.add(chainId);
      _evmChainErrors.remove(chainId);
    });
    try {
      final assets = await evmService.loadBalances(chainId, address);
      if (!mounted) return;
      setState(() => _evmAssetsByChain[chainId] = assets);
    } catch (e) {
      // 单链查询失败不影响其他链，但必须让用户看到并可以重试
      if (!mounted) return;
      setState(() => _evmChainErrors[chainId] = e.toString());
    } finally {
      if (mounted) {
        setState(() => _evmLoadingChains.remove(chainId));
      }
    }
  }

  /// 重试指定 EVM 链的余额查询。
  void _retryEvmChain(String chainId) {
    final wallet = _currentWallet;
    if (wallet == null || !wallet.isEvm) return;
    _loadEvmChainBalances(wallet.address, chainId);
  }

  /// 切换 EVM 链下拉列表。
  ///
  /// 若目标链已有缓存余额则立即显示，否则触发异步加载。
  void _switchEvmChain(String chainId) {
    if (chainId == _selectedEvmChainId) return;
    setState(() => _selectedEvmChainId = chainId);
    if (_evmAssetsByChain.containsKey(chainId)) return;
    final wallet = _currentWallet;
    if (wallet == null || !wallet.isEvm) return;
    _loadEvmChainBalances(wallet.address, chainId);
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
    final currentEvmAssets = _selectedEvmChainId != null
        ? _evmAssetsByChain[_selectedEvmChainId] ?? []
        : <EvmAssetBalance>[];
    final evmNativeBalance = currentEvmAssets
        .where((a) => a.isNative)
        .firstOrNull;
    final isCurrentChainLoading =
        _selectedEvmChainId != null &&
        _evmLoadingChains.contains(_selectedEvmChainId);
    final currentChainError = _selectedEvmChainId != null
        ? _evmChainErrors[_selectedEvmChainId]
        : null;

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
                    _buildMainBalance(adaBalance, 'ADA'),
                  if (wallet.isCardano && adaBalance == null)
                    const SizedBox(height: 32),
                  if (wallet.isEvm && isCurrentChainLoading)
                    _buildChainLoadingIndicator(),
                  if (wallet.isEvm &&
                      !isCurrentChainLoading &&
                      currentChainError != null)
                    _buildChainErrorRow(_selectedEvmChainId!),
                  if (wallet.isEvm &&
                      !isCurrentChainLoading &&
                      currentChainError == null &&
                      evmNativeBalance != null)
                    _buildMainBalance(
                      evmNativeBalance.formattedBalance,
                      evmNativeBalance.symbol,
                    ),
                  if (wallet.isEvm &&
                      !isCurrentChainLoading &&
                      currentChainError == null &&
                      evmNativeBalance == null)
                    const SizedBox(height: 32),
                  const SizedBox(height: 32),
                  _buildActionButtons(wallet),
                  const SizedBox(height: 32),
                  _buildAssetsHeader(),
                  const SizedBox(height: 8),
                  _buildAssetsList(wallet),
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
                  if (wallet.isEvm) ...[
                    const SizedBox(width: 8),
                    _buildEvmChainSelector(),
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

  /// EVM 链下拉选择器（紧凑样式，嵌入地址行）
  ///
  /// 显示当前选中链的名称，点击可切换到其他 EVM 链。
  /// 切换后优先使用缓存余额，无缓存时触发异步加载。
  Widget _buildEvmChainSelector() {
    final evmConfigs = ChainRegistry.configsForFamily('evm');
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedEvmChainId,
        isDense: true,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
        icon: const Icon(Icons.keyboard_arrow_down, size: 14),
        items: evmConfigs
            .map(
              (c) => DropdownMenuItem(
                value: c.chainId,
                child: Text(c.name, style: const TextStyle(fontSize: 12)),
              ),
            )
            .toList(),
        onChanged: (v) => v != null ? _switchEvmChain(v) : null,
      ),
    );
  }

  /// 当前 EVM 链查询中：余额区显示小型加载指示器（ADR-0008）。
  Widget _buildChainLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }

  /// 当前 EVM 链查询失败：行内错误态 + 重试按钮，与“余额为 0”区分（ADR-0008 缺陷 D2）。
  Widget _buildChainErrorRow(String chainId) {
    return Row(
      children: [
        Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
        const SizedBox(width: 8),
        const Expanded(child: Text('该链查询失败')),
        TextButton(
          onPressed: () => _retryEvmChain(chainId),
          child: const Text('重试'),
        ),
      ],
    );
  }

  Widget _buildMainBalance(String balance, String symbol) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$balance $symbol',
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

  Widget _buildAssetsHeader() {
    return Text(
      '代币',
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildAssetsList(WatchWallet wallet) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (wallet.isEvm) {
      // 加载中/失败时代币区不显示“暂无 ERC-20”提示，避免误导（ADR-0008）
      final chainId = _selectedEvmChainId;
      if (chainId != null && _evmLoadingChains.contains(chainId)) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      if (chainId != null && _evmChainErrors.containsKey(chainId)) {
        // 错误态已在余额区行内展示，此处留白
        return const SizedBox(height: 24);
      }
      final currentEvm = _selectedEvmChainId != null
          ? _evmAssetsByChain[_selectedEvmChainId] ?? []
          : <EvmAssetBalance>[];
      if (currentEvm.length <= 1) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text('暂无 ERC-20 代币，请到设置页添加'),
        );
      }
      final tokens = currentEvm.where((a) => !a.isNative).toList();
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tokens.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final asset = tokens[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(asset.symbol),
            subtitle: Text(
              asset.contractAddress ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(asset.formattedBalance),
          );
        },
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
