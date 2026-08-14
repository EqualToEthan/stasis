import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'tx_detail_screen.dart';

/// 扫描交易二维码页面
///
/// 使用摄像头扫描联网设备展示的未签名交易二维码，
/// 验证为 JSON 后跳转到交易详情页。
class ScanTxScreen extends StatefulWidget {
  const ScanTxScreen({super.key});

  @override
  State<ScanTxScreen> createState() => _ScanTxScreenState();
}

class _ScanTxScreenState extends State<ScanTxScreen> {
  bool _scanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;

    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _scanned = true);

    try {
      jsonDecode(rawValue); // validate JSON
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TxDetailScreen(rawJson: rawValue),
        ),
      );
    } catch (e) {
      setState(() => _scanned = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法解析二维码: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描交易二维码')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Positioned(
            top: 100,
            left: 40,
            right: 40,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '将二维码对准框内',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  shadows: [Shadow(blurRadius: 4)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
