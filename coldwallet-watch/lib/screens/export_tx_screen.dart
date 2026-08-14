import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/cold_export.dart';
import '../widgets/qr_display.dart';

/// 导出未签名交易页面
///
/// 将构建好的未签名交易以二维码、JSON 文本和文件三种方式导出，
/// 供冷钱包端离线签名。提供“下一步：导入签名结果”引导完成闭环。
class ExportTxScreen extends StatelessWidget {
  const ExportTxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coldExport = ModalRoute.of(context)!.settings.arguments as ColdExport;
    final jsonStr = jsonEncode(coldExport.toJson());

    Future<void> copyJson() async {
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已复制 JSON 到剪贴板')));
      }
    }

    Future<void> saveFile() async {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(
          '${dir.path}/unsigned_tx_${DateTime.now().millisecondsSinceEpoch}.json',
        );
        await file.writeAsString(jsonStr);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('文件已保存: ${file.path}')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('导出未签名交易')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('二维码', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Center(child: QRDisplay(data: jsonStr)),
            const SizedBox(height: 24),
            const Text(
              'JSON 文本',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(jsonStr, maxLines: 5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: copyJson,
                    icon: const Icon(Icons.copy),
                    label: const Text('复制 JSON'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saveFile,
                    icon: const Icon(Icons.save),
                    label: const Text('保存文件'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/import-signed');
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('下一步：导入签名结果'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
