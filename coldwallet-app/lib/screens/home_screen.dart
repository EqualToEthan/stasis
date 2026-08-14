import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/chain_registry.dart';
import '../models/wallet_info.dart';
import '../services/wallet_service.dart';
import 'tx_detail_screen.dart';

/// 冷钱包首页
///
/// 展示钱包选择器、网络切换、扫码签名入口、文件导入入口和钱包管理入口。
/// 无钱包时引导用户创建第一个钱包。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WalletService _walletService = WalletService();

  List<WalletInfo> _wallets = [];
  WalletInfo? _currentWallet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final wallets = await _walletService.getWallets();
    final current = await _walletService.getCurrentWallet();
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _currentWallet = current;
      _isLoading = false;
    });
  }

  bool get _hasWallets => _wallets.isNotEmpty;

  void _showWalletPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '切换钱包',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              ..._wallets.map((wallet) {
                final isSelected = wallet.id == _currentWallet?.id;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.account_balance_wallet_outlined,
                    color: isSelected ? Theme.of(context).primaryColor : null,
                  ),
                  title: Text(wallet.name),
                  subtitle: Text(
                    wallet.createdAt.toLocal().toString().split('.').first,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  selected: isSelected,
                  onTap: () async {
                    await _walletService.switchWallet(wallet.id);
                    if (context.mounted) Navigator.pop(context);
                    await _loadState();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stasis'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWalletSelector(),
                  if (_hasWallets) ...[
                    const SizedBox(height: 16),
                    _buildMultiChainAddressList(),
                  ],
                  const SizedBox(height: 24),
                  _buildActionButton(
                    icon: Icons.qr_code_scanner,
                    label: '扫码签名',
                    description: '扫描联网设备上的未签名交易二维码',
                    onPressed: _hasWallets
                        ? () async {
                            await Navigator.pushNamed(context, '/scan-tx');
                            if (mounted) _loadState();
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    icon: Icons.file_open,
                    label: '导入签名',
                    description: '从文件导入未签名交易',
                    onPressed: _hasWallets
                        ? () => _showImportDialog(context)
                        : null,
                  ),
                  if (_hasWallets) ...[
                    const SizedBox(height: 16),
                    _buildActionButton(
                      icon: Icons.settings,
                      label: '钱包管理',
                      description: '查看地址、备份助记词、管理钱包',
                      onPressed: () async {
                        await Navigator.pushNamed(context, '/wallet-setup');
                        if (mounted) _loadState();
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入未签名交易'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _pickAndImportFile();
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('从文件导入'),
            ),
            const SizedBox(height: 12),
            const Text('或粘贴 JSON 数据：'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '粘贴 ColdExport JSON',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _parseAndNavigate(controller.text.trim());
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImportFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt', 'cbor'],
      );
      if (file == null) return;
      final path = file.path;
      if (path == null) return;
      final content = await File(path).readAsString();
      _parseAndNavigate(content.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('读取文件失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _parseAndNavigate(String jsonStr) {
    if (jsonStr.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('数据不能为空')));
      return;
    }
    try {
      // Validate JSON, then pass raw string
      jsonDecode(jsonStr);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TxDetailScreen(rawJson: jsonStr),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解析失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildWalletSelector() {
    if (!_hasWallets) {
      return GestureDetector(
        onTap: () async {
          await Navigator.pushNamed(context, '/wallet-setup');
          if (mounted) _loadState();
        },
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '尚无钱包，点击创建',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _showWalletPicker,
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentWallet?.name ?? '未知钱包',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      '${_wallets.length} 个钱包',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.swap_vert,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, String>> _loadAllAddresses() async {
    final mnemonic = await _walletService.loadCurrentMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) return {};
    return _walletService.deriveAllAddresses(mnemonic);
  }

  String _truncate(String value, {int head = 12, int tail = 12}) {
    if (value.length <= head + tail + 3) return value;
    return '${value.substring(0, head)}...${value.substring(value.length - tail)}';
  }

  void _copyAddress(String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('地址已复制')));
  }

  Widget _buildMultiChainAddressList() {
    return FutureBuilder<Map<String, String>>(
      future: _loadAllAddresses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('地址派生失败: ${snapshot.error}'),
            ),
          );
        }

        final addresses = snapshot.data ?? const <String, String>{};
        if (addresses.isEmpty) {
          return const Card(
            child: Padding(padding: EdgeInsets.all(16), child: Text('暂无地址')),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('多链地址', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final config in ChainRegistry.allConfigs())
              if (addresses[config.chainId] != null)
                Card(
                  child: ListTile(
                    title: Text(config.name),
                    subtitle: Text(
                      _truncate(addresses[config.chainId]!),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: '复制地址',
                      onPressed: () => _copyAddress(addresses[config.chainId]!),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
