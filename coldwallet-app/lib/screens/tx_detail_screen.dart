import 'package:flutter/material.dart';

import '../models/cold_export.dart';
import 'confirm_sign_screen.dart';

/// 交易详情页面
///
/// 展示未签名交易的摘要信息（网络、发送方、接收方、金额、手续费），
/// 用户确认后跳转到 PIN 验证签名页面。
class TxDetailScreen extends StatelessWidget {
  final ColdExport coldExport;

  const TxDetailScreen({super.key, required this.coldExport});

  String _formatAda(String lovelace) {
    try {
      final value = int.parse(lovelace);
      return '${(value / 1000000).toStringAsFixed(6)} ADA';
    } catch (_) {
      return '$lovelace lovelace';
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
    return Scaffold(
      appBar: AppBar(title: const Text('交易详情')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(
              title: '网络',
              value: coldExport.network,
              icon: Icons.network_check,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: '发送方',
              value: coldExport.summary.fromAddress,
              icon: Icons.arrow_upward,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: '接收方',
              value: coldExport.summary.toAddress,
              icon: Icons.arrow_downward,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: '金额',
              value: coldExport.summary.assets.map(_formatAsset).join('\n'),
              icon: Icons.paid,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: '手续费',
              value: _formatAda(coldExport.summary.fee),
              icon: Icons.receipt,
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ConfirmSignScreen(coldExport: coldExport),
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('确认并签名'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
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
