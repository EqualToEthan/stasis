import 'package:flutter/material.dart';

/// 关于页面
///
/// 展示应用名称、版本号和简短说明。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cold Wallet Watch',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('版本 1.0.0', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 24),
            Text(
              '联网观察钱包，用于查看余额、构建未签名交易，并通过二维码或剪贴板与离线冷钱包交互。',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
