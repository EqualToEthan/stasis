import 'package:flutter/material.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';

import '../services/evm_rpc_config.dart';
import '../services/storage_service.dart';
import 'evm_rpc_edit_screen.dart';

/// EVM RPC 链列表页
///
/// 以摘要形式列出当前网络下的所有 EVM 链，
/// 显示每条链当前使用的是默认 RPC 还是用户自定义 RPC。
/// 点击某条链进入详情页编辑 RPC 端点。
class EvmRpcChainListScreen extends StatefulWidget {
  /// 可选的 StorageService 注入，主要用于测试。
  final StorageService? storageService;

  const EvmRpcChainListScreen({super.key, this.storageService});

  @override
  State<EvmRpcChainListScreen> createState() => _EvmRpcChainListScreenState();
}

class _EvmRpcChainListScreenState extends State<EvmRpcChainListScreen> {
  late StorageService _storage;
  bool _loading = true;
  final Map<String, String?> _customUrls = {};

  List<ChainConfig> get _chains => ChainRegistry.configsForFamily('evm');

  @override
  void initState() {
    super.initState();
    _loadCustomUrls();
  }

  Future<void> _loadCustomUrls() async {
    final storage = widget.storageService ?? await StorageService.create();
    for (final chain in _chains) {
      _customUrls[chain.chainId] = await storage.getEvmRpcUrl(chain.chainId);
    }
    if (!mounted) return;
    setState(() {
      _storage = storage;
      _loading = false;
    });
  }

  Future<void> _navigateEdit(ChainConfig chain) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EvmRpcEditScreen(chain: chain, storageService: _storage),
      ),
    );
    // 编辑页返回后刷新自定义 URL 状态
    if (changed == true) {
      final updated = await _storage.getEvmRpcUrl(chain.chainId);
      setState(() => _customUrls[chain.chainId] = updated);
    }
  }

  String _statusText(String chainId) {
    final custom = _customUrls[chainId];
    if (custom != null && custom.isNotEmpty) {
      final visible = custom.length > 30
          ? '${custom.substring(0, 30)}...'
          : custom;
      return '自定义：$visible';
    }
    return '默认 RPC';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('EVM RPC 端点')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _chains.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final chain = _chains[index];
          return Card(
            child: ListTile(
              title: Text(chain.name),
              subtitle: Text(_statusText(chain.chainId)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _navigateEdit(chain),
            ),
          );
        },
      ),
    );
  }
}
