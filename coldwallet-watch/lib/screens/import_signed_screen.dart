import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/cold_import.dart';
import '../services/blockfrost_service.dart';
import '../services/storage_service.dart';
import '../widgets/qr_scanner.dart';

/// 导入已签名交易页面
///
/// 支持三种导入方式：扫描二维码、从文件导入、粘贴 JSON。
/// 解析 ColdImport 数据后通过 Blockfrost 提交到链上。
class ImportSignedScreen extends StatefulWidget {
  const ImportSignedScreen({super.key});

  @override
  State<ImportSignedScreen> createState() => _ImportSignedScreenState();
}

class _ImportSignedScreenState extends State<ImportSignedScreen> {
  bool _submitting = false;

  Future<void> _parseAndSubmit(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final coldImport = ColdImport.fromJson(data);
      await _submit(coldImport);
    } catch (e) {
      _showError('解析签名文件失败: $e');
    }
  }

  Future<void> _submit(ColdImport coldImport) async {
    setState(() => _submitting = true);
    try {
      final storage = await StorageService.create();
      final apiKey = await storage.getBlockfrostApiKey();
      final network = await storage.getCurrentNetwork();
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

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return;
    final path = result.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    await _parseAndSubmit(content.trim());
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
              child: Column(
                children: [
                  Expanded(child: QRScanner(onScan: _parseAndSubmit)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('从文件导入'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pasteJson,
                          icon: const Icon(Icons.paste),
                          label: const Text('粘贴 JSON'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
