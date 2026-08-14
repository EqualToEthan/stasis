import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../services/wallet_service.dart';

/// 添加只读钱包页面
///
/// 用户输入钱包名称和 Cardano 地址，
/// 验证地址格式后保存到本地存储。
class AddWalletScreen extends StatefulWidget {
  const AddWalletScreen({super.key});

  @override
  State<AddWalletScreen> createState() => _AddWalletScreenState();
}

class _AddWalletScreenState extends State<AddWalletScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  late WalletService _walletService;
  final String _network = 'preview';
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    final storage = await StorageService.create();
    _walletService = WalletService(storage);
    if (!mounted) return;
    setState(() => _initialized = true);
  }

  Future<void> _save() async {
    if (!_initialized) return;
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    if (name.isEmpty || address.isEmpty) {
      _showError('名称和地址不能为空');
      return;
    }
    if (!_walletService.validateAddress(address)) {
      _showError('地址格式不正确');
      return;
    }
    setState(() => _saving = true);
    try {
      await _walletService.addWallet(
        name: name,
        address: address,
        network: _network,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('保存失败: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加只读钱包')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '钱包名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Cardano 地址',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_saving || !_initialized) ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
