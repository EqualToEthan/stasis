import 'package:flutter/material.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';

import '../services/storage_service.dart';
import 'manage_evm_tokens_screen.dart';

/// 代币管理入口页
///
/// 按链分组列出可管理代币的入口。
/// 当前仅支持 EVM 链的 ERC-20 代币；点击某条链进入该链的代币列表。
class TokenManagementScreen extends StatefulWidget {
  /// 可选的 StorageService 注入，主要用于测试。
  final StorageService? storageService;

  const TokenManagementScreen({super.key, this.storageService});

  @override
  State<TokenManagementScreen> createState() => _TokenManagementScreenState();
}

class _TokenManagementScreenState extends State<TokenManagementScreen> {
  late StorageService _storage;
  bool _loading = true;

  List<ChainConfig> get _chains => ChainRegistry.configsForFamily('evm');

  @override
  void initState() {
    super.initState();
    _initStorage();
  }

  Future<void> _initStorage() async {
    final storage = widget.storageService ?? await StorageService.create();
    if (!mounted) return;
    setState(() {
      _storage = storage;
      _loading = false;
    });
  }

  Future<void> _navigateChainTokens(ChainConfig chain) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManageEvmTokensScreen(
          storageService: _storage,
          initialChainId: chain.chainId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('代币管理')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _chains.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final chain = _chains[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.token),
              title: Text(chain.name),
              subtitle: const Text('管理该链的 ERC-20 代币'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _navigateChainTokens(chain),
            ),
          );
        },
      ),
    );
  }
}
