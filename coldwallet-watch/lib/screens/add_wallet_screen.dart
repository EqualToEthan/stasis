import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../services/wallet_service.dart';
import '../widgets/qr_scanner.dart';

/// 添加只读钱包页面
///
/// 用户选择链族（Cardano / EVM），输入钱包名称和地址（支持 QR 扫描），
/// 验证地址格式后保存到本地存储。
/// Cardano 链支持 QR 扫描合并地址：`{"paymentAddress": "...", "stakeAddress": "..."}`。
/// EVM 链支持选择具体 chainId（Sepolia / BSC Testnet 等）。
class AddWalletScreen extends StatefulWidget {
  const AddWalletScreen({super.key});

  @override
  State<AddWalletScreen> createState() => _AddWalletScreenState();
}

/// EVM 链选项：显示名称 → chainId
const _evmChainOptions = <MapEntry<String, String>>[
  MapEntry('Ethereum Sepolia', 'sepolia'),
  MapEntry('BSC Testnet', 'bsc-testnet'),
  MapEntry('Arbitrum Sepolia', 'arbitrum-sepolia'),
  MapEntry('Polygon Amoy', 'polygon-amoy'),
  MapEntry('Base Sepolia', 'base-sepolia'),
];

class _AddWalletScreenState extends State<AddWalletScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _stakeAddressController = TextEditingController();
  late WalletService _walletService;
  final String _network = 'preview';
  bool _initialized = false;
  bool _saving = false;
  bool _showingScanner = false;

  // 链选择状态：null 表示尚未选择（等待扫码自动检测或手动选择）
  String? _chainFamily;
  String? _evmChainId = _evmChainOptions.first.value;

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
  /// 支持三种格式：
  /// - JSON 合并格式（Cardano）：`{"paymentAddress": "...", "stakeAddress": "..."}`
  /// - 纯地址字符串（Cardano bech32 或 EVM hex）
  /// 自动检测链类型并切换下拉选择器。
  void _handleQrResult(String raw) {
    setState(() => _showingScanner = false);

    final trimmed = raw.trim();

    // 尝试解析为 JSON（Cardano 合并地址格式）
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
          // JSON 合并格式一定是 Cardano
          setState(() => _chainFamily = 'cardano');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                stakeAddress != null
                    ? '已识别 Cardano 合并地址（含 stake address）'
                    : '已识别 Cardano 支付地址',
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // JSON 解析失败，尝试作为纯地址处理
      }
    }

    // 纯地址：自动检测链类型
    final detected = _walletService.detectChainFamily(trimmed);
    if (detected != null) {
      setState(() => _chainFamily = detected);
    }

    _addressController.text = trimmed;
    final chainLabel = detected == 'evm'
        ? 'EVM'
        : detected == 'cardano'
        ? 'Cardano'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(chainLabel.isNotEmpty ? '已识别 $chainLabel 地址' : '已识别地址'),
      ),
    );
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
    if (_chainFamily == null) {
      _showError('请先选择链类型或扫描二维码');
      return;
    }
    if (!_walletService.validateAddress(address, _chainFamily!)) {
      final chainLabel = _chainFamily == 'evm' ? 'EVM' : 'Cardano';
      _showError('$chainLabel 地址格式不正确');
      return;
    }
    // Cardano 专属校验：stake address 格式
    if (_chainFamily == 'cardano' &&
        stakeAddress.isNotEmpty &&
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
        stakeAddress: _chainFamily == 'cardano' && stakeAddress.isNotEmpty
            ? stakeAddress
            : null,
        chainFamily: _chainFamily!,
        chainId: _chainFamily == 'evm' ? _evmChainId : null,
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
            // 链族选择器（初始无预选，由扫码自动检测或手动选择）
            DropdownButtonFormField<String>(
              initialValue: _chainFamily,
              decoration: const InputDecoration(
                labelText: '链类型',
                border: OutlineInputBorder(),
              ),
              hint: const Text('扫码自动识别 或 手动选择'),
              items: const [
                DropdownMenuItem(value: 'cardano', child: Text('Cardano')),
                DropdownMenuItem(
                  value: 'evm',
                  child: Text('EVM (Ethereum / BSC / ...)'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _chainFamily = value;
                    // 切换链时清空地址和 stake address
                    _addressController.clear();
                    _stakeAddressController.clear();
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            // 地址输入框（标签随链类型变化，未选择时显示通用标签）
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _chainFamily == null
                    ? '地址'
                    : _chainFamily == 'evm'
                    ? 'EVM 地址'
                    : 'Cardano 地址',
                hintText: _chainFamily == null
                    ? '扫码自动识别 或 手动输入'
                    : _chainFamily == 'evm'
                    ? '0x...'
                    : 'addr_test1...',
                border: const OutlineInputBorder(),
              ),
            ),
            // Cardano 专属：stake address 字段
            if (_chainFamily == 'cardano') ...[
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
            ],
            // EVM 专属：chainId 选择
            if (_chainFamily == 'evm') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _evmChainId,
                decoration: const InputDecoration(
                  labelText: 'EVM 链',
                  border: OutlineInputBorder(),
                ),
                items: _evmChainOptions
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.value, child: Text(e.key)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _evmChainId = value);
                  }
                },
              ),
            ],
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
