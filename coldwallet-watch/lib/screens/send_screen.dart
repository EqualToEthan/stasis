import 'package:flutter/material.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import '../models/watch_wallet.dart';
import '../services/blockfrost_service.dart';
import '../services/storage_service.dart';
import '../services/tx_builder_service.dart';

/// 发起转账页面
///
/// 用户输入收款地址、选择资产和数量，
/// 构建未签名交易后跳转到导出页面。
class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  WatchWallet? _wallet;
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedUnit = 'lovelace';
  bool _building = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is WatchWallet) {
        setState(() => _wallet = args);
      }
    });
  }

  Future<void> _buildTx() async {
    final wallet = _wallet;
    if (wallet == null) return;
    final toAddress = _addressController.text.trim();
    final amount = _amountController.text.trim();
    if (toAddress.isEmpty || amount.isEmpty) {
      _showError('收款地址和金额不能为空');
      return;
    }
    if (toAddress == wallet.address) {
      _showError('不能转账给自己');
      return;
    }

    setState(() => _building = true);
    try {
      final storage = await StorageService.create();
      final apiKey = await storage.getBlockfrostApiKey() ?? '';
      final blockfrost = BlockfrostService(
        apiKey: apiKey,
        network: wallet.network,
      );
      final txBuilder = TxBuilderService(blockfrost);
      final coldExport = await txBuilder.buildTransferTx(
        fromAddress: wallet.address,
        toAddress: toAddress,
        assets: [AssetAmount(unit: _selectedUnit, quantity: amount)],
        network: wallet.network,
      );
      if (mounted) {
        Navigator.pushNamed(context, '/export-tx', arguments: coldExport);
      }
    } catch (e) {
      _showError('构建交易失败: $e');
    } finally {
      setState(() => _building = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    if (wallet == null) {
      return const Scaffold(body: Center(child: Text('无钱包数据')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('发起转账')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '收款地址',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _selectedUnit,
              decoration: const InputDecoration(labelText: '资产'),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedUnit = value);
                }
              },
              items: const [
                DropdownMenuItem(value: 'lovelace', child: Text('ADA')),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '数量（lovelace 或 token 单位）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _building ? null : _buildTx,
                child: _building
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('下一步'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
