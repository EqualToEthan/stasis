import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../services/wallet_service.dart';
import '../widgets/qr_scanner.dart';

/// 添加只读钱包页面
///
/// 用户输入钱包名称和 Cardano 地址（支持 QR 扫描合并地址），
/// 验证地址格式后保存到本地存储。
/// QR 扫描支持合并格式：`{"paymentAddress": "...", "stakeAddress": "..."}`。
class AddWalletScreen extends StatefulWidget {
  const AddWalletScreen({super.key});

  @override
  State<AddWalletScreen> createState() => _AddWalletScreenState();
}

class _AddWalletScreenState extends State<AddWalletScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _stakeAddressController = TextEditingController();
  late WalletService _walletService;
  final String _network = 'preview';
  bool _initialized = false;
  bool _saving = false;
  bool _showingScanner = false;

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

  /// 处理 QR 扫描结果
  ///
  /// 支持两种格式：
  /// - 纯地址字符串（Cardano bech32 地址）
  /// - JSON 合并格式：`{"paymentAddress": "...", "stakeAddress": "..."}`
  void _handleQrResult(String raw) {
    setState(() => _showingScanner = false);

    // 尝试解析为 JSON（合并地址格式）
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) {
      try {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        final paymentAddress = json['paymentAddress'] as String?;
        final stakeAddress = json['stakeAddress'] as String?;
        if (paymentAddress != null && paymentAddress.isNotEmpty) {
          _addressController.text = paymentAddress;
          if (stakeAddress != null && stakeAddress.isNotEmpty) {
            _stakeAddressController.text = stakeAddress;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                stakeAddress != null ? '已识别合并地址（含 stake address）' : '已识别支付地址',
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // JSON 解析失败，尝试作为纯地址处理
      }
    }

    // 作为纯地址处理
    _addressController.text = trimmed;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已识别地址')));
  }

  Future<void> _save() async {
    if (!_initialized) return;
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final stakeAddress = _stakeAddressController.text.trim();

    if (name.isEmpty || address.isEmpty) {
      _showError('名称和地址不能为空');
      return;
    }
    if (!_walletService.validateAddress(address)) {
      _showError('地址格式不正确');
      return;
    }
    if (stakeAddress.isNotEmpty &&
        !stakeAddress.startsWith('stake_test1') &&
        !stakeAddress.startsWith('stake1')) {
      _showError('Stake address 格式不正确，应以 stake_test1 或 stake1 开头');
      return;
    }

    setState(() => _saving = true);
    try {
      await _walletService.addWallet(
        name: name,
        address: address,
        stakeAddress: stakeAddress.isNotEmpty ? stakeAddress : null,
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
    if (_showingScanner) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('扫描二维码'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _showingScanner = false),
          ),
        ),
        body: QRScanner(onScan: _handleQrResult),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('添加只读钱包')),
      body: SingleChildScrollView(
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
            const SizedBox(height: 16),
            TextField(
              controller: _stakeAddressController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Stake Address（可选）',
                hintText: 'stake_test1...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: '清除',
                  onPressed: () => _stakeAddressController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '可通过扫描二维码同时导入支付地址和 stake address',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving || !_initialized
                    ? null
                    : () => setState(() => _showingScanner = true),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('扫描二维码'),
              ),
            ),
            const SizedBox(height: 16),
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
