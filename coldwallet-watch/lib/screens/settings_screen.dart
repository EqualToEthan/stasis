import 'package:flutter/material.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';

import '../services/storage_service.dart';

/// 设置页面
///
/// 显示当前网络信息（由 coldwallet-protocol 中 `AppConfig.isMainnet`
/// 全局开关决定），提供 Blockfrost API Key 的配置入口。
/// 网络切换不在运行时 UI 中进行，修改全局开关后两端同步生效。
class SettingsScreen extends StatefulWidget {
  /// 可选的 StorageService 注入，主要用于测试。
  final StorageService? storageService;

  const SettingsScreen({super.key, this.storageService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  Future<void> _saveSettings() async {
    await _storage.setBlockfrostApiKey(_apiKeyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saveSettings,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
