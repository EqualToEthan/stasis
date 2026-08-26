import 'package:flutter/material.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import '../models/watch_wallet.dart';
import '../services/blockfrost_service.dart';
import '../services/storage_service.dart';
import '../widgets/info_card.dart';

/// 治理委托页面
///
/// 当前阶段为只读展示页。本应用仅支持默认弃权（abstain），弃权证书随
/// 质押交易自动附带（ADR 0004），用户无需手动操作。
/// 页面展示当前 stake key 的治理委托状态，用于透明度与未来扩展。
class GovernanceDelegationScreen extends StatefulWidget {
  /// 可选的 Blockfrost 服务注入，用于测试。
  final BlockfrostService? blockfrostService;

  const GovernanceDelegationScreen({super.key, this.blockfrostService});

  @override
  State<GovernanceDelegationScreen> createState() =>
      _GovernanceDelegationScreenState();
}

class _GovernanceDelegationScreenState
    extends State<GovernanceDelegationScreen> {
  WatchWallet? _wallet;

  /// 当前网络标识，由 AppConfig.isMainnet 决定
  String get _currentNetwork => AppConfig.isMainnet ? 'mainnet' : 'preview';

  // 治理委托状态
  bool _loadingStatus = true;
  String? _statusError;
  Map<String, dynamic>? _stakeInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is WatchWallet) {
        setState(() => _wallet = args);
        _loadGovernanceStatus(args);
      }
    });
  }

  Future<void> _loadGovernanceStatus(WatchWallet wallet) async {
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
      final blockfrost = await _createBlockfrost();
      final info = await blockfrost.getStakeAccountInfo(wallet.stakeAddress!);
      if (!mounted) return;
      setState(() {
        _stakeInfo = info;
        _loadingStatus = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusError = '查询治理委托状态失败: $e';
        _loadingStatus = false;
      });
    }
  }

  Future<BlockfrostService> _createBlockfrost() async {
    if (widget.blockfrostService != null) return widget.blockfrostService!;
    final storage = await StorageService.create();
    final apiKey = await storage.getBlockfrostApiKey() ?? '';
    return BlockfrostService(apiKey: apiKey, network: _currentNetwork);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    if (wallet == null) {
      return const Scaffold(body: Center(child: Text('无钱包数据')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('治理委托')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(wallet),
            const SizedBox(height: 24),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(WatchWallet wallet) {
    if (wallet.stakeAddress == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(child: Text('该钱包没有 stake address，无法查看治理委托状态')),
            ],
          ),
        ),
      );
    }

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

    final poolId = info['pool_id'] as String?;
    final drepId = info['drep_id'] as String?;

    // Blockfrost 对 abstain 委托的 drep_id 返回行为未文档化，
    // 非 bech32 的非空值（如 always_abstain）也按弃权展示。
    final String status;
    final String detail;
    if (drepId != null &&
        drepId.isNotEmpty &&
        (drepId.startsWith('drep1') || drepId.startsWith('drep_script1'))) {
      status = '已委托';
      detail = '已委托给外部 DRep（${_shortDRepId(drepId)}）';
    } else if (drepId != null && drepId.isNotEmpty) {
      status = '已默认弃权';
      detail = '弃权（外部操作或系统自动）';
    } else if (poolId != null) {
      status = '已默认弃权';
      detail = '弃权（随质押自动完成）';
    } else {
      status = '未设置';
      detail = '尚未质押；完成首次质押后将自动弃权';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoCard(title: '治理委托状态', value: status, icon: Icons.account_balance),
        const SizedBox(height: 12),
        InfoCard(title: '详情', value: detail, icon: Icons.info_outline),
      ],
    );
  }

  String _shortDRepId(String drepId) {
    if (drepId.length <= 20) return drepId;
    return '${drepId.substring(0, 10)}...${drepId.substring(drepId.length - 6)}';
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '关于治理委托',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '本应用当前仅支持默认弃权（abstain），即不参与治理投票。'
              '当你在「质押」页面完成首次 Stake Pool 质押时，系统会自动附带弃权证书，'
              '无需在此页面手动操作。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
