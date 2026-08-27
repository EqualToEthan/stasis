import 'package:flutter/material.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';

import '../services/storage_service.dart';
import 'evm_rpc_chain_list_screen.dart';

/// 网络与 API 设置页
///
/// 展示当前网络环境（只读）、Blockfrost API Key 设置，
/// 并提供 EVM RPC 端点设置的入口。
class NetworkApiSettingsScreen extends StatefulWidget {
  /// 可选的 StorageService 注入，主要用于测试。
  final StorageService? storageService;

  const NetworkApiSettingsScreen({super.key, this.storageService});

  @override
  State<NetworkApiSettingsScreen> createState() =>
      _NetworkApiSettingsScreenState();
}

class _NetworkApiSettingsScreenState extends State<NetworkApiSettingsScreen> {
  late StorageService _storage;
  final _apiKeyController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = widget.storageService ?? await StorageService.create();
    final apiKey = await storage.getBlockfrostApiKey();

    if (!mounted) return;
    setState(() {
      _storage = storage;
      _apiKeyController.text = apiKey ?? '';
      _loading = false;
    });
  }

  Future<void> _saveApiKey() async {
    await _storage.setBlockfrostApiKey(_apiKeyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('API Key 已保存')));
    }
  }

  Future<void> _navigateEvmRpc() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvmRpcChainListScreen(storageService: _storage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('网络与 API')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 网络信息
          const Text('网络', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            AppConfig.isMainnet ? 'Mainnet 主网' : 'Preview 测试网',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '全局网络开关控制，修改 AppConfig.isMainnet 后两端同步生效。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Blockfrost API Key
          const Text(
            'Blockfrost API Key',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              hintText: '输入 Blockfrost Project ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saveApiKey,
              child: const Text('保存 API Key'),
            ),
          ),
          const SizedBox(height: 24),

          // EVM RPC 入口
          const Text('EVM 链', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_ethernet),
              title: const Text('EVM RPC 端点'),
              subtitle: const Text('设置各 EVM 链的自定义 RPC 节点'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _navigateEvmRpc,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}
