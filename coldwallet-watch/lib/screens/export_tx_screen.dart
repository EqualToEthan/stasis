import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import '../widgets/qr_display.dart';

/// 导出未签名交易页面
///
/// 将构建好的未签名交易以二维码和 JSON 文本两种方式导出，
/// 供冷钱包端离线签名。交易详情（发送方、接收方、金额、手续费等）
/// 在 coldwallet-app 签名页展示，本页只保留最简导出入口。
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

    return Scaffold(
      appBar: AppBar(title: const Text('导出未签名交易')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '请使用冷钱包端扫描下方二维码，或复制 JSON 文本进行签名',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              '二维码',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
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
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: copyJson,
                icon: const Icon(Icons.copy),
                label: const Text('复制 JSON'),
              ),
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
