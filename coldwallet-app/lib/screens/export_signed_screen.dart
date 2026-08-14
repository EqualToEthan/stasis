import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 已签名交易导出页面
///
/// 展示签名后的交易哈希、完整 CBOR 二维码，并提供复制功能。
/// 如果交易数据超过二维码容量，会提示用户改用复制方式传输。
class ExportSignedScreen extends StatelessWidget {
  final Map<String, dynamic> signedJson;

  const ExportSignedScreen({super.key, required this.signedJson});

  String get _payload => jsonEncode(signedJson);

  /// QR 码二进制容量上限（Version 40, 低容错）
  static const int _maxQrBytes = 2953;

  bool get _qrFits => _payload.length <= _maxQrBytes;

  void _copyPayload(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _payload));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制完整签名数据')));
  }

  void _copyTxHash(BuildContext context) {
    Clipboard.setData(ClipboardData(text: signedJson['txHash'] as String));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制交易哈希')));
  }

  String _truncate(String value, {int head = 12, int tail = 12}) {
    if (value.length <= head + tail + 3) return value;
    return '${value.substring(0, head)}...${value.substring(value.length - tail)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('签名完成')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              '交易已签名',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '请在联网设备上导入以下数据完成提交',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('交易哈希', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SelectableText(
                      _truncate(signedJson['txHash'] as String),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _copyTxHash(context),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('复制交易哈希'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_qrFits) ...[
              Center(
                child: QrImageView(
                  data: _payload,
                  version: QrVersions.auto,
                  size: 280,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (context, error) {
                    return Text(
                      '生成二维码失败: $error',
                      style: const TextStyle(color: Colors.red),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '扫描二维码导入已签名交易',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(child: Text('交易数据较大，超出了二维码容量，请使用复制功能传输。')),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _copyPayload(context),
              icon: const Icon(Icons.copy),
              label: const Text('复制完整签名数据'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              ),
              icon: const Icon(Icons.home),
              label: const Text('返回首页'),
            ),
          ],
        ),
      ),
    );
  }
}
