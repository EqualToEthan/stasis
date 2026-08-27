import 'package:flutter/material.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';

import '../services/evm_rpc_config.dart';
import '../services/storage_service.dart';

/// 单条 EVM 链的 RPC 端点编辑页
///
/// 允许用户输入自定义 RPC URL 覆盖默认值，或恢复使用默认公共 RPC。
/// 保存成功后通过 Navigator 返回 `true`，调用方可据此刷新列表状态。
class EvmRpcEditScreen extends StatefulWidget {
  /// 目标链配置。
  final ChainConfig chain;

  /// 可选的 StorageService 注入，主要用于测试。
  final StorageService? storageService;

  const EvmRpcEditScreen({super.key, required this.chain, this.storageService});

  @override
  State<EvmRpcEditScreen> createState() => _EvmRpcEditScreenState();
}

class _EvmRpcEditScreenState extends State<EvmRpcEditScreen> {
  late StorageService _storage;
  final _urlController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomUrl();
  }

  Future<void> _loadCustomUrl() async {
    final storage = widget.storageService ?? await StorageService.create();
    final custom = await storage.getEvmRpcUrl(widget.chain.chainId);

    if (!mounted) return;
    setState(() {
      _storage = storage;
      _urlController.text = custom ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    await _storage.setEvmRpcUrl(widget.chain.chainId, url.isEmpty ? null : url);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('RPC 端点已保存')));
      Navigator.pop(context, true);
    }
  }

  void _restoreDefault() {
    _urlController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final defaultUrl = EvmRpcConfig.getDefaultRpcUrl(widget.chain.chainId);

    return Scaffold(
      appBar: AppBar(title: Text(widget.chain.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('自定义 RPC URL', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: defaultUrl ?? 'https://...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.restore),
                  tooltip: '恢复默认',
                  onPressed: _restoreDefault,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '留空将使用默认公共 RPC。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (defaultUrl != null) ...[
              const SizedBox(height: 4),
              Text(
                '默认：$defaultUrl',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('保存')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
