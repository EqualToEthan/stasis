import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import '../services/blockfrost_service.dart';
import '../services/storage_service.dart';
import '../widgets/info_card.dart';
import '../widgets/qr_scanner.dart';

/// 导入已签名交易页面
///
/// 支持两种导入方式：扫描二维码、粘贴 JSON。
/// 解析 ColdImport 数据后通过 Blockfrost 提交到链上。
class ImportSignedScreen extends StatefulWidget {
  const ImportSignedScreen({super.key});

  @override
  State<ImportSignedScreen> createState() => _ImportSignedScreenState();
}

class _ImportSignedScreenState extends State<ImportSignedScreen> {
  bool _submitting = false;
  bool _showScanner = false;

  Future<void> _parseAndSubmit(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final coldImport = ColdImport.fromJson(data);
      await _confirmAndSubmit(coldImport);
    } catch (e) {
      _showError('解析签名数据失败: $e');
    }
  }

  /// 显示确认对话框，用户确认后才提交交易到链上。
  ///
  /// 提交链上交易是不可逆操作，所有导入方式（扫码、粘贴）
  /// 在提交前都必须经过用户确认。
  Future<void> _confirmAndSubmit(ColdImport coldImport) async {
    final txCborPreview = coldImport.txCbor.length > 64
        ? '${coldImport.txCbor.substring(0, 64)}...'
        : coldImport.txCbor;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认导入签名结果'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoCard(
                title: '交易哈希',
                value: coldImport.txHash,
                icon: Icons.tag,
              ),
              const SizedBox(height: 12),
              InfoCard(
                title: '签名数据',
                value: txCborPreview,
                icon: Icons.data_object,
              ),
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '提交后将向链上广播此交易，操作不可撤销。',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认提交'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submit(coldImport);
    }
  }

  Future<void> _submit(ColdImport coldImport) async {
    setState(() => _submitting = true);
    try {
      final storage = await StorageService.create();
      final apiKey = await storage.getBlockfrostApiKey();
      final network = AppConfig.isMainnet ? 'mainnet' : 'preview';
      if (apiKey == null || apiKey.isEmpty) {
        _showError('请先设置 Blockfrost API Key');
        return;
      }
      final blockfrost = BlockfrostService(apiKey: apiKey, network: network);
      final txBytes = Uint8List.fromList(
        List<int>.generate(
          coldImport.txCbor.length ~/ 2,
          (i) => int.parse(
            coldImport.txCbor.substring(i * 2, i * 2 + 2),
            radix: 16,
          ),
        ),
      );
      final txHash = await blockfrost.submitTx(txBytes);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('提交成功'),
            content: SelectableText('TxHash: $txHash'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showError('提交失败: $e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _pasteJson() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text;
    if (text == null || text.isEmpty) {
      _showError('剪贴板为空');
      return;
    }
    await _parseAndSubmit(text.trim());
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入签名结果')),
      body: _submitting
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: _showScanner ? _buildScanner() : _buildMethodSelector(),
            ),
    );
  }

  /// 导入方式选择面板
  ///
  /// 默认显示两种导入方式，避免进入页面直接打开摄像头。
  Widget _buildMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '请选择导入方式',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _ImportMethodCard(
          icon: Icons.qr_code_scanner,
          title: '扫描二维码',
          subtitle: '扫描冷钱包端展示的签名结果二维码',
          onTap: () => setState(() => _showScanner = true),
        ),
        const SizedBox(height: 12),
        _ImportMethodCard(
          icon: Icons.paste,
          title: '粘贴 JSON',
          subtitle: '从剪贴板粘贴签名结果 JSON',
          onTap: _pasteJson,
        ),
      ],
    );
  }

  /// 二维码扫描面板
  ///
  /// 用户主动选择扫码后展示，并提供返回选择面板的入口。
  Widget _buildScanner() {
    return Column(
      children: [
        Expanded(child: QRScanner(onScan: _parseAndSubmit)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showScanner = false),
            icon: const Icon(Icons.arrow_back),
            label: const Text('选择其他方式'),
          ),
        ),
      ],
    );
  }
}

/// 导入方式卡片
class _ImportMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImportMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
