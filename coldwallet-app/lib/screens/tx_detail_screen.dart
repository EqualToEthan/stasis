import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'confirm_sign_screen.dart';

/// Transaction detail screen with chain-aware rendering.
class TxDetailScreen extends StatelessWidget {
  final String rawJson;

  const TxDetailScreen({super.key, required this.rawJson});

  String _formatAda(String lovelace) {
    try {
      final value = int.parse(lovelace);
      return '${(value / 1000000).toStringAsFixed(6)} ADA';
    } catch (_) {
      return '$lovelace lovelace';
    }
  }

  String _formatWei(String wei) {
    try {
      final value = BigInt.parse(wei);
      final divisor = BigInt.from(10).pow(18);
      return '${(value.toDouble() / divisor.toDouble()).toStringAsFixed(6)} ETH';
    } catch (_) {
      return '$wei wei';
    }
  }

  String _formatAsset(AssetAmount asset) {
    if (asset.unit == 'lovelace') {
      return _formatAda(asset.quantity);
    }
    return '${asset.quantity} ${asset.displayLabel}';
  }

  @override
  Widget build(BuildContext context) {
    final json = jsonDecode(rawJson) as Map<String, dynamic>;
    final chainId = json['chainId'] as String?;

    if (chainId == null) {
      final coldExport = ColdExport.fromJson(json);
      return _buildCardanoDetail(context, coldExport);
    }

    final config = ChainRegistry.getConfig(chainId);
    if (config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('\u9519\u8bef')),
        body: Center(child: Text('\u4e0d\u652f\u6301\u7684\u94fe: $chainId')),
      );
    }

    if (config.chainFamily == 'evm') {
      final ethExport = EthColdExport.fromJson(json);
      return _buildEvmDetail(context, ethExport, config.name);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('\u9519\u8bef')),
      body: Center(
        child: Text(
          '\u4e0d\u652f\u6301\u7684\u94fe\u65cf: ${config.chainFamily}',
        ),
      ),
    );
  }

  /// 构建 Cardano 交易详情视图。
  ///
  /// 展示网络、发送方、接收方、金额、手续费和可选的押金信息。
  /// deposit 为正数时显示「押金」（注册），负数时显示「退回押金」（解除注册）。
  /// 有奖励提取时额外显示「提取奖励」卡片，
  /// 含 voteDelegation 证书时显示「DRep 委托」卡片。
  Widget _buildCardanoDetail(BuildContext context, ColdExport coldExport) {
    final deposit = coldExport.summary.deposit;
    final hasDeposit = deposit != null && deposit != '0';
    final isRefund = hasDeposit && deposit.startsWith('-');
    final withdrawals = coldExport.withdrawals;
    final hasWithdrawals = withdrawals != null && withdrawals.isNotEmpty;
    final voteDelegation = coldExport.certificates
        ?.where((c) => c.type == CertificateType.voteDelegation)
        .firstOrNull;
    final hasVoteDelegation = voteDelegation != null;

    return Scaffold(
      appBar: AppBar(title: const Text('\u4ea4\u6613\u8be6\u60c5')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoCard(
                title: '\u7f51\u7edc',
                value: coldExport.network,
                icon: Icons.network_check,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                title: '\u53d1\u9001\u65b9',
                value: coldExport.summary.fromAddress,
                icon: Icons.arrow_upward,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                title: '\u63a5\u6536\u65b9',
                value: coldExport.summary.toAddress,
                icon: Icons.arrow_downward,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                title: '\u91d1\u989d',
                value: coldExport.summary.assets.map(_formatAsset).join('\n'),
                icon: Icons.paid,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                title: '\u624b\u7eed\u8d39',
                value: _formatAda(coldExport.summary.fee),
                icon: Icons.receipt,
              ),
              if (hasDeposit) ...[
                const SizedBox(height: 12),
                _buildInfoCard(
                  title: isRefund ? '\u9000\u56de\u62bc\u91d1' : '\u62bc\u91d1',
                  value: _formatAda(isRefund ? deposit.substring(1) : deposit),
                  icon: isRefund ? Icons.lock_open : Icons.lock,
                ),
              ],
              if (hasWithdrawals) ...[
                const SizedBox(height: 12),
                _buildInfoCard(
                  title: '\u63d0\u53d6\u5956\u52b1',
                  value: withdrawals.entries
                      .map((e) => '${_formatAda(e.value.toString())} ADA')
                      .join('\n'),
                  icon: Icons.savings,
                ),
              ],
              if (hasVoteDelegation) ...[
                const SizedBox(height: 12),
                _buildInfoCard(
                  title: 'DRep \u59d4\u6258',
                  value: _describeDRep(voteDelegation),
                  icon: Icons.account_balance,
                ),
              ],
              const SizedBox(height: 24),
              _buildConfirmButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 生成 DRep 委托的人类可读描述。
  ///
  /// abstain / noConfidence 为固定文案；
  /// keyHash / scriptHash 展示截断的 hash（保留前后各 8 字符）。
  String _describeDRep(Certificate cert) {
    switch (cert.dRepType) {
      case DRepType.abstain:
        return '\u5f03\u6743\uff08abstain\uff09';
      case DRepType.noConfidence:
        return '\u4e0d\u4fe1\u4efb\uff08no confidence\uff09';
      case DRepType.keyHash:
      case DRepType.scriptHash:
        final hash = cert.dRepHash ?? '';
        if (hash.length <= 20) return hash;
        return '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}';
      case null:
        return '\u672a\u77e5\u7c7b\u578b';
    }
  }

  Widget _buildEvmDetail(
    BuildContext context,
    EthColdExport ethExport,
    String chainName,
  ) {
    return Scaffold(
      appBar: AppBar(title: const Text('\u4ea4\u6613\u8be6\u60c5')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(title: '\u94fe', value: chainName, icon: Icons.hub),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: '\u53d1\u9001\u65b9',
              value: ethExport.summary.fromAddress,
              icon: Icons.arrow_upward,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: '\u63a5\u6536\u65b9',
              value: ethExport.summary.toAddress,
              icon: Icons.arrow_downward,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: '\u91d1\u989d',
              value: _formatWei(ethExport.summary.value),
              icon: Icons.paid,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: '\u624b\u7eed\u8d39',
              value: _formatWei(ethExport.summary.fee),
              icon: Icons.receipt,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: 'Nonce',
              value: ethExport.summary.nonce.toString(),
              icon: Icons.tag,
            ),
            const Spacer(),
            _buildConfirmButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmSignScreen(rawJson: rawJson),
          ),
        );
      },
      icon: const Icon(Icons.edit),
      label: const Text('\u786e\u8ba4\u5e76\u7b7e\u540d'),
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blueGrey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
