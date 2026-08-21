import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/watch_wallet.dart';
import '../services/blockfrost_service.dart';
import '../services/stake_transaction_builder.dart';
import '../services/storage_service.dart';

/// 质押管理页面
///
/// 展示当前质押状态（委托池、可提取奖励），提供三种操作入口：
/// 委托（首次注册+委托，或已委托时重新委托）、提取奖励、解除注册。
/// 构建的未签名交易通过 [ColdExport] 传递给冷钱包签名。
class StakingScreen extends StatefulWidget {
  /// 可选的 Blockfrost 服务注入，用于测试。
  final BlockfrostService? blockfrostService;

  const StakingScreen({super.key, this.blockfrostService});

  @override
  State<StakingScreen> createState() => _StakingScreenState();
}

class _StakingScreenState extends State<StakingScreen> {
  WatchWallet? _wallet;
  final _poolIdController = TextEditingController();

  // 质押状态
  bool _loadingStatus = true;
  String? _statusError;
  Map<String, dynamic>? _stakeInfo;

  // 操作状态
  bool _building = false;
  String _selectedAction = 'delegate';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is WatchWallet) {
        setState(() => _wallet = args);
        _loadStakingStatus(args);
      }
    });
  }

  @override
  void dispose() {
    _poolIdController.dispose();
    super.dispose();
  }

  Future<void> _loadStakingStatus(WatchWallet wallet) async {
    if (wallet.stakeAddress == null) {
      setState(() {
        _loadingStatus = false;
        _statusError = '该钱包没有 stake address，请重新导入钱包时包含 stake address';
      });
      return;
    }
    setState(() {
      _loadingStatus = true;
      _statusError = null;
    });
    try {
      final blockfrost = await _createBlockfrost(wallet.network);
      final info = await blockfrost.getStakeAccountInfo(wallet.stakeAddress!);
      if (!mounted) return;
      setState(() {
        _stakeInfo = info;
        _loadingStatus = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusError = '查询质押状态失败: $e';
        _loadingStatus = false;
      });
    }
  }

  Future<BlockfrostService> _createBlockfrost(String network) async {
    if (widget.blockfrostService != null) return widget.blockfrostService!;
    final storage = await StorageService.create();
    final apiKey = await storage.getBlockfrostApiKey() ?? '';
    return BlockfrostService(apiKey: apiKey, network: network);
  }

  Future<void> _buildDelegate() async {
    final wallet = _wallet;
    if (wallet == null || wallet.stakeAddress == null) return;

    final poolId = _poolIdController.text.trim();
    if (poolId.isEmpty) {
      _showError('请输入 Stake Pool ID');
      return;
    }
    if (!poolId.startsWith('pool1')) {
      _showError('Pool ID 格式不正确，应以 pool1 开头');
      return;
    }

    setState(() => _building = true);
    try {
      final blockfrost = await _createBlockfrost(wallet.network);

      // 校验 pool 是否已退役
      final retired = await blockfrost.isPoolRetired(poolId);
      if (retired) {
        _showError('该 Stake Pool 已退役，请选择其他 Pool');
        return;
      }

      final isActive = _stakeInfo?['active'] == true;
      final builder = StakeTransactionBuilder(blockfrost);
      final coldExport = await builder.buildDelegate(
        fromAddress: wallet.address,
        stakeAddress: wallet.stakeAddress!,
        poolIdBech32: poolId,
        network: wallet.network,
        isStakeRegistered: isActive,
      );
      if (mounted) {
        Navigator.pushNamed(context, '/export-tx', arguments: coldExport);
      }
    } catch (e) {
      _showError('构建委托交易失败: $e');
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  Future<void> _buildWithdraw() async {
    final wallet = _wallet;
    if (wallet == null || wallet.stakeAddress == null) return;

    final rewardAmount =
        BigInt.tryParse(
          (_stakeInfo?['withdrawable_amount'] ?? '0').toString(),
        ) ??
        BigInt.zero;

    if (rewardAmount <= BigInt.zero) {
      _showError('没有可提取的奖励');
      return;
    }

    setState(() => _building = true);
    try {
      final blockfrost = await _createBlockfrost(wallet.network);
      final builder = StakeTransactionBuilder(blockfrost);
      final coldExport = await builder.buildWithdrawReward(
        fromAddress: wallet.address,
        stakeAddress: wallet.stakeAddress!,
        withdrawableAmount: rewardAmount,
        network: wallet.network,
      );
      if (mounted) {
        Navigator.pushNamed(context, '/export-tx', arguments: coldExport);
      }
    } catch (e) {
      _showError('构建提取奖励交易失败: $e');
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  Future<void> _buildDeregister() async {
    final wallet = _wallet;
    if (wallet == null || wallet.stakeAddress == null) return;

    final isActive = _stakeInfo?['active'] == true;
    if (!isActive) {
      _showError('Stake key 尚未注册，无需解除');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认解除注册'),
        content: const Text(
          '解除 stake key 注册后，将退回 2 ADA deposit。\n'
          '当前委托关系也将终止。\n\n确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _building = true);
    try {
      final blockfrost = await _createBlockfrost(wallet.network);
      final builder = StakeTransactionBuilder(blockfrost);
      final coldExport = await builder.buildDeregister(
        fromAddress: wallet.address,
        stakeAddress: wallet.stakeAddress!,
        network: wallet.network,
      );
      if (mounted) {
        Navigator.pushNamed(context, '/export-tx', arguments: coldExport);
      }
    } catch (e) {
      _showError('构建解除注册交易失败: $e');
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _copyStakeAddress() async {
    final addr = _wallet?.stakeAddress;
    if (addr == null) return;
    await Clipboard.setData(ClipboardData(text: addr));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Stake address 已复制')));
  }

  String _formatAda(String lovelace) {
    final value = BigInt.parse(lovelace);
    final ada = value ~/ BigInt.from(1000000);
    final remainder = value % BigInt.from(1000000);
    final remainderStr = remainder.toString().padLeft(6, '0');
    final trimmed = remainderStr.replaceAll(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? '$ada' : '$ada.$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    if (wallet == null) {
      return const Scaffold(body: Center(child: Text('无钱包数据')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('质押管理')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStakeAddressCard(wallet),
            const SizedBox(height: 16),
            _buildStatusCard(wallet),
            const SizedBox(height: 24),
            _buildActionTabs(),
            const SizedBox(height: 16),
            _buildActionPanel(wallet),
          ],
        ),
      ),
    );
  }

  Widget _buildStakeAddressCard(WatchWallet wallet) {
    final stakeAddr = wallet.stakeAddress;
    if (stakeAddr == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange),
              const SizedBox(width: 12),
              const Expanded(child: Text('该钱包没有 stake address，无法进行质押操作')),
            ],
          ),
        ),
      );
    }

    final short = stakeAddr.length > 20
        ? '${stakeAddr.substring(0, 12)}...${stakeAddr.substring(stakeAddr.length - 8)}'
        : stakeAddr;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.key),
        title: const Text('Stake Address'),
        subtitle: Text(short, style: const TextStyle(fontFamily: 'monospace')),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 20),
          tooltip: '复制',
          onPressed: _copyStakeAddress,
        ),
      ),
    );
  }

  Widget _buildStatusCard(WatchWallet wallet) {
    if (wallet.stakeAddress == null) return const SizedBox.shrink();

    if (_loadingStatus) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_statusError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(child: Text(_statusError!)),
            ],
          ),
        ),
      );
    }

    final info = _stakeInfo;
    if (info == null) return const SizedBox.shrink();

    final isActive = info['active'] == true;
    final poolId = info['pool_id'] as String?;
    final rewardAmount = info['withdrawable_amount']?.toString() ?? '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '质押状态',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _infoRow('状态', isActive ? '已注册' : '未注册'),
            if (poolId != null) _infoRow('当前委托池', _shortPoolId(poolId)),
            _infoRow('可提取奖励', '${_formatAda(rewardAmount)} ADA'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _shortPoolId(String poolId) {
    if (poolId.length <= 20) return poolId;
    return '${poolId.substring(0, 10)}...${poolId.substring(poolId.length - 6)}';
  }

  Widget _buildActionTabs() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'delegate',
          label: Text('委托'),
          icon: Icon(Icons.how_to_vote),
        ),
        ButtonSegment(
          value: 'withdraw',
          label: Text('提取奖励'),
          icon: Icon(Icons.savings),
        ),
        ButtonSegment(
          value: 'deregister',
          label: Text('解除注册'),
          icon: Icon(Icons.person_remove),
        ),
      ],
      selected: {_selectedAction},
      onSelectionChanged: (selection) {
        setState(() => _selectedAction = selection.first);
      },
    );
  }

  Widget _buildActionPanel(WatchWallet wallet) {
    switch (_selectedAction) {
      case 'delegate':
        return _buildDelegatePanel(wallet);
      case 'withdraw':
        return _buildWithdrawPanel(wallet);
      case 'deregister':
        return _buildDeregisterPanel(wallet);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDelegatePanel(WatchWallet wallet) {
    if (wallet.stakeAddress == null) {
      return const Text('请先导入 stake address');
    }

    final poolId = _stakeInfo?['pool_id'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 已委托时展示当前委托信息作为提示，但不阻断 re-delegation
        if (poolId != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '当前已委托到 ${_shortPoolId(poolId)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _poolIdController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Stake Pool ID（bech32 格式）',
            hintText: 'pool1...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          poolId != null
              ? '如需更换委托池，直接输入新的 Pool ID 即可重新委托。'
              : '输入目标 Stake Pool 的 bech32 ID。如果 stake key 尚未注册，会自动包含注册操作（需 2 ADA 押金）。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _building ? null : _buildDelegate,
            child: _building
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('构建委托交易'),
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawPanel(WatchWallet wallet) {
    if (wallet.stakeAddress == null) {
      return const Text('请先导入 stake address');
    }

    final rewardAmount = _stakeInfo?['withdrawable_amount']?.toString() ?? '0';
    final hasReward =
        (BigInt.tryParse(rewardAmount) ?? BigInt.zero) > BigInt.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('可提取奖励'),
                Text(
                  '${_formatAda(rewardAmount)} ADA',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_building || !hasReward) ? null : _buildWithdraw,
            child: _building
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('提取奖励'),
          ),
        ),
      ],
    );
  }

  Widget _buildDeregisterPanel(WatchWallet wallet) {
    if (wallet.stakeAddress == null) {
      return const Text('请先导入 stake address');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('解除注册后将退回 2 ADA deposit，同时终止当前委托关系。'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _building ? null : _buildDeregister,
            child: _building
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('解除 Stake Key 注册'),
          ),
        ),
      ],
    );
  }
}
