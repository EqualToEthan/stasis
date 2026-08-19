import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/chain_registry.dart';
import '../models/wallet_info.dart';
import '../services/wallet_service.dart';
import 'scan_tx_screen.dart';
import 'tx_detail_screen.dart';

/// 冷钱包首页
///
/// 展示钱包选择器、多链地址下拉切换、扫码签名入口、文件导入入口和钱包管理入口。
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

  // 多链地址缓存与下拉选中状态
  Map<String, String> _allAddresses = {};
  bool _addressesLoading = true;
  String? _selectedChainId;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  /// 加载钱包列表、当前钱包和多链地址并缓存到状态。
  ///
  /// 地址在加载后缓存到 [_allAddresses]，下拉切换链时直接读取缓存，
  /// 避免每次切换都重新派生地址。切换钱包后若选中的链不可用则回退到第一条。
  Future<void> _loadState() async {
    final wallets = await _walletService.getWallets();
    final current = await _walletService.getCurrentWallet();
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _currentWallet = current;
      _isLoading = false;
    });

    // 加载多链地址并缓存到状态，避免下拉切换时重新派生
    if (current != null) {
      setState(() => _addressesLoading = true);
      try {
        final addresses = await _loadAllAddresses();
        final available = ChainRegistry.allConfigs()
            .where((c) => addresses[c.chainId] != null)
            .toList();
        if (!mounted) return;
        setState(() {
          _allAddresses = addresses;
          _addressesLoading = false;
          // 切换钱包后若当前选中链不存在则回退到第一条
          if (_selectedChainId == null ||
              !available.any((c) => c.chainId == _selectedChainId)) {
            _selectedChainId = available.isNotEmpty
                ? available.first.chainId
                : null;
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _allAddresses = {};
          _addressesLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('地址派生失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      if (!mounted) return;
      setState(() {
        _allAddresses = {};
        _addressesLoading = false;
        _selectedChainId = null;
      });
    }
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
                    onPressed: _hasWallets && _selectedChainId != null
                        ? () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScanTxScreen(
                                  requiredChainId: _selectedChainId!,
                                ),
                              ),
                            );
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
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 链联动校验：导入的交易链必须与当前选中链一致
      if (_selectedChainId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前无可用链，请先创建钱包')));
        return;
      }
      final scannedChainId = ChainRegistry.resolveChainId(json);
      final mismatch = ChainRegistry.mismatchMessage(
        _selectedChainId!,
        scannedChainId,
      );
      if (mismatch != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mismatch)));
        return;
      }

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

  /// 构建多链地址下拉选择器。
  ///
  /// 通过 [DropdownButtonFormField] 切换链，下方只显示当前选中链的地址卡片。
  /// 地址数据来自 [_loadState] 缓存的 [_allAddresses]，切换时无需重新派生。
  Widget _buildMultiChainAddressList() {
    if (_addressesLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_allAddresses.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16), child: Text('暂无地址')),
      );
    }

    final availableConfigs = ChainRegistry.allConfigs()
        .where((c) => _allAddresses[c.chainId] != null)
        .toList();

    if (availableConfigs.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16), child: Text('暂无地址')),
      );
    }

    final selectedConfig = availableConfigs.firstWhere(
      (c) => c.chainId == _selectedChainId,
      orElse: () => availableConfigs.first,
    );
    final selectedAddress = _allAddresses[selectedConfig.chainId]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('多链地址', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedConfig.chainId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: availableConfigs.map((config) {
            return DropdownMenuItem<String>(
              value: config.chainId,
              child: Text(config.name),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedChainId = value);
            }
          },
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: Text(selectedConfig.name),
            subtitle: Text(
              _truncate(selectedAddress),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              tooltip: '复制地址',
              onPressed: () => _copyAddress(selectedAddress),
            ),
          ),
        ),
      ],
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
